use async_std::io::{BufReader, BufWriter};
use async_std::net::{TcpListener, TcpStream};
use async_std::prelude::*;
use async_std::task;
use futures::stream::{self, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::Number;
use std::env;
use std::fmt::Write;
use std::sync::atomic::AtomicU64;
use sysinfo::{CpuExt, CpuRefreshKind, System, SystemExt};
use tracing::{error, info};

const MAX_CPU_PCT: f32 = 90.0;
const MAX_MEM_PCT: f32 = 0.9;
const CONNECTION_BUF_SIZE: usize = 1024;
const MAX_CONN_QUEUE_SIZE: usize = 1024;
const SYS_STAT_UPDATE_INTERVAL_MS: u64 = 10; // millis

#[async_std::main]
async fn main() {
    tracing_subscriber::fmt::try_init().unwrap();

    let bind_addr = env::var("BIND_ADDR").unwrap_or("127.0.0.1".to_string());
    let bind_port: u16 = env::var("BIND_PORT")
        .unwrap_or("10001".to_string())
        .parse()
        .expect("BIND_PORT must be a number");
    println!("Hello, world!");

    let listener = TcpListener::bind((bind_addr.as_str(), bind_port))
        .await
        .expect("Failed to bind to address");

    info!("Listening on {}", listener.local_addr().unwrap());

    let num_in_progress_connections = AtomicU64::new(0);
    let num_queued_connections = AtomicU64::new(0);

    let sys_stats = system_stat_stream();

    listener
        .incoming()
        .zip(sys_stats)
        .for_each_concurrent(
            /* limit */ None,
            |(maybe_stream, current_sys_stats)| async move {
                // let mut sys_stats_clone = sys_stats.clone();
                let stream = maybe_stream.expect("Failed to accept connection");
                if current_sys_stats.is_overloaded() {
                    info!(
                        "Rejecting connection due to overload: {}",
                        current_sys_stats.resource_usage_desc()
                    );
                    stream
                        .shutdown(std::net::Shutdown::Both)
                        .expect("Failed to shutdown stream");
                } else {
                    info!("Accepted connection from {:?}", stream.peer_addr());
                    task::spawn(handle_connection(stream));
                }
            },
        )
        .await;
}

fn stream_conn_id(stream: &TcpStream) -> String {
    stream.peer_addr().unwrap().to_string()
}

#[derive(Debug, Serialize, Deserialize)]
struct IsPrimeRequest {
    method: String,
    number: Number,
}

struct IsPrimeResponse {
    method: String,
    isPrime: bool,
}

struct ReadState {
    stream: TcpStream,
    reader: BufReader<TcpStream>,
    writer: BufWriter<TcpStream>,
}

struct WriteState {
    stream: TcpStream,
    reader: BufReader<TcpStream>,
    writer: BufWriter<TcpStream>,
    request: IsPrimeRequest,
}

#[derive(Debug)]
enum IsPrimeError {
    MalformedRequest,
    IoError(std::io::Error),
}

enum IsPrimeService {
    ReadRequest(ReadState),
    RespondToConformingRequest(WriteState),
    Finished(TcpStream),
    Shutdown(TcpStream),
    HandleError(TcpStream, IsPrimeError),
}
impl IsPrimeService {
    fn new(stream: TcpStream) -> IsPrimeService {
        IsPrimeService::ReadRequest(ReadState {
            stream,
            reader: BufReader::new(stream),
            writer: BufWriter::new(stream),
        })
    }

    fn is_done(&self) -> bool {
        match self {
            IsPrimeService::Shutdown(_) => true,
            _ => false,
        }
    }

    async fn next_state(self) -> IsPrimeService {
        match self {
            IsPrimeService::ReadRequest(state) => {
                let buf = String::new();
                state
                    .reader
                    .read_line(&mut buf)
                    .await
                    .map_err(|e| IsPrimeError::IoError(e))
                    .and_then(|n| {
                        info!("{}: Read {} bytes", stream_conn_id(&state.stream), n);
                        if n > 0 {
                            serde_json::from_str(&buf)
                                .map(|r: IsPrimeRequest| {
                                    info!(
                                        "{}: Received and decoded request: {:?}",
                                        stream_conn_id(&state.stream),
                                        r
                                    );
                                    IsPrimeService::RespondToConformingRequest(WriteState {
                                        stream: state.stream,
                                        reader: state.reader,
                                        writer: state.writer,
                                        request: r,
                                    })
                                })
                                .map_err(|e| IsPrimeError::MalformedRequest)
                        } else {
                            Ok(IsPrimeService::Finished(state.stream))
                        }
                    })
                    .unwrap_or_else(|e| IsPrimeService::HandleError(state.stream, e))
            }
            IsPrimeService::RespondToConformingRequest(state) => {
                match stream.write_all(&buf[..bytes_to_write]).await {
                    Ok(_) => {
                        info!(
                            "{}: Wrote {} bytes",
                            stream_conn_id(&stream),
                            bytes_to_write,
                        );
                        IsPrimeService::ReadRequest(stream, buf)
                    }
                    Err(e) => IsPrimeService::HandleError(stream, e),
                }
            }
            IsPrimeService::Finished(stream) => {
                info!("Reached EOF, closing stream...");
                match stream.shutdown(std::net::Shutdown::Both) {
                    Ok(_) => IsPrimeService::Shutdown(stream),
                    Err(e) => {
                        info!("Failed to shutdown stream: {}", e);
                        IsPrimeService::Shutdown(stream)
                    }
                }
            }
            IsPrimeService::HandleError(stream, e) => {
                error!(
                    "{}: TCP stream error: {}, closing stream...",
                    stream_conn_id(&stream),
                    e
                );
                match stream.shutdown(std::net::Shutdown::Both) {
                    Ok(_) => IsPrimeService::Shutdown(stream),
                    Err(e) => {
                        info!("Failed to shutdown stream: {}", e);
                        IsPrimeService::Shutdown(stream)
                    }
                }
            }
            IsPrimeService::Shutdown(s) => IsPrimeService::Shutdown(s),
        }
    }
}

async fn handle_connection(stream: TcpStream) {
    let mut echoer = IsPrimeService::new(stream);
    loop {
        echoer = echoer.next_state().await;
        if echoer.is_done() {
            break;
        }
    }
}

#[derive(Clone)]
struct SystemStats {
    cpu_pct: f32,
    mem_pct: f32,
    last_update: std::time::Instant,
}
impl SystemStats {
    fn is_overloaded(&self) -> bool {
        self.cpu_pct > MAX_CPU_PCT || self.mem_pct > MAX_MEM_PCT
    }
    fn resource_usage_desc(&self) -> String {
        format!(
            "CPU usage = {:.2}%, Mem usage = {:.2}%",
            self.cpu_pct, self.mem_pct
        )
    }
}

struct SystemStatsStreamState {
    current_stats: SystemStats,
    system: System,
}

fn system_stat_stream() -> impl Stream<Item = SystemStats> {
    let state = SystemStatsStreamState {
        current_stats: SystemStats {
            cpu_pct: 0.0,
            mem_pct: 0.0,
            last_update: std::time::Instant::now(),
        },
        system: System::new(),
    };

    stream::unfold(state, |mut state| async move {
        let now = std::time::Instant::now();

        let old_stats = state.current_stats.clone();
        if now.duration_since(old_stats.last_update)
            > std::time::Duration::from_millis(SYS_STAT_UPDATE_INTERVAL_MS)
        {
            state
                .system
                .refresh_cpu_specifics(CpuRefreshKind::new().with_cpu_usage());
            state.system.refresh_memory();

            let new_stats = SystemStats {
                cpu_pct: state.system.global_cpu_info().cpu_usage(),
                mem_pct: state.system.used_memory() as f32 / state.system.total_memory() as f32,
                last_update: std::time::Instant::now(),
            };

            Some((
                new_stats.clone(),
                SystemStatsStreamState {
                    current_stats: new_stats,
                    system: state.system,
                },
            ))
        } else {
            Some((state.current_stats.clone(), state))
        }
    })
}
