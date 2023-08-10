#!/bin/bash

set -eo pipefail

PROB_NUM=$1

cd /opt/protohacker
aws s3 cp s3://protohacker-solutions/problem${PROB_NUM} protohacker${PROB_NUM}
chmod +x protohacker${PROB_NUM}
chown protohackers:protohackers protohacker${PROB_NUM}