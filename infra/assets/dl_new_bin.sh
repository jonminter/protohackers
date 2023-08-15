#!/bin/bash

PROB_NUM=$1
if [ -z "$PROB_NUM" ]; then
    echo "Please provide a problem number!"
    exit 1
fi

function log() {
    msg=$1
    now=$(date --iso-8601=seconds)
    echo "${now}: ${msg}"
}

{
    set -e
    set -o pipefail

    log "Downloading problem ${PROB_NUM} from S3..."
    set -x
    cd /opt/protohacker
    aws s3 cp s3://protohacker-solutions/problem${PROB_NUM} protohacker${PROB_NUM}
    chmod +x protohacker${PROB_NUM}
    chown protohackers:protohackers protohacker${PROB_NUM}
    set +x

    log "Downloading service definition from S3..."
    set -x
    aws s3 cp s3://protohacker-solutions/protohacker${PROB_NUM}.service /etc/systemd/system/protohacker${PROB_NUM}.service
    set +x

    log "Reloading systemd daemon and starting service..."
    set -x
    systemctl daemon-reload
    systemctl start protohacker${PROB_NUM}
    set +x
} 2>&1 | tee /tmp/deployment-${PROB_NUM}.log 2>&1 

set +x
log "Uploading problem deployment log to S3..."
aws s3 cp /tmp/deployment-${PROB_NUM}.log s3://protohacker-solutions/deploy-logs/problem-deploy-${PROB_NUM}-$(date --iso-8601=seconds).log

