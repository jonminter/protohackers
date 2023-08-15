#!/bin/bash


# install AWS CLI
# install EC2 Instance Connect
# install protohacker binary
function log() {
    msg=$1
    now=$(date --iso-8601=seconds)
    echo "${now}: ${msg}"
}

{
    set -e
    set -o pipefail
    log "Starting deployment..."
    log "Updating yum and installing packages..."
    set -x
    yum update -y
    set +x
    log "Installing ec2-instance-connect, tar, gzip, unzip, and systemctl..."
    set -x
    yum install -y ec2-instance-connect tar gzip unzip /usr/bin/systemctl
    set +x

    log "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    set -x
    unzip awscliv2.zip
    ./aws/install
    set +x

    log "Creating protohackers user..."
    set -x
    useradd protohackers
    
    log "Creating protohackers install dir..."
    set -x
    mkdir -p /opt/protohacker
    chown protohackers:protohackers /opt/protohacker
    set +x

    log "Downloading problem deployment script..."
    set -x
    aws s3 cp s3://protohacker-solutions/dl_new_bin.sh /opt/protohacker/dl_new_bin.sh
    chmod +x /opt/protohacker/dl_new_bin.sh
    chown protohackers:protohackers /opt/protohacker/dl_new_bin.sh
    set +x

    log "Downloading and deploying problem 0: Smoketest..."
    set -x
    /opt/protohacker/dl_new_bin.sh 0
    set +x

    log "${now}: Deployment complete!"
} 2>&1 | tee /tmp/setup-host.log

set +x
aws s3 cp /tmp/setup-host.log s3://protohacker-solutions/deploy-logs/setup-host-$(date --iso-8601=seconds).log