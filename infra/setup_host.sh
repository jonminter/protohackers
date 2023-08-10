#!/bin/bash

set -ex
set -o pipefail
# install AWS CLI
# install EC2 Instance Connect
# install protohacker binary

yum update -y
yum install -y ec2-instance-connect tar gzip unzip /usr/bin/systemctl

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

mkdir -p /opt/protohacker
cd /opt/protohacker
aws s3 cp s3://protohackers-solutions/problem0_smoketest protohacker0-smoketest

cat <<EOF > /usr/lib/systemd/system/protohacker0-smoketest.service
[Unit]
Description=Protohacker Problem 0: Smoketest

[Service]
ExecStart=/opt/protohacker/protohacker0-smoketest
ExecReload=/bin/kill -HUP $MAINPID
killMode=process
Restart=on-failure
RestartSec=42s
EOF

systemctl daemon-reload