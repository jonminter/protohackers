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

useradd protohackers

mkdir -p /opt/protohacker
chown protohackers:protohackers /opt/protohacker
cd /opt/protohacker
aws s3 cp s3://protohacker-solutions/problem0_smoketest protohacker0-smoketest
chmod +x protohacker0-smoketest
chown protohackers:protohackers protohacker0-smoketest

cat <<EOF > /usr/lib/systemd/system/protohacker0-smoketest.service
[Unit]
Description=Protohacker Problem 0: Smoketest

[Service]
User=protohackers
Environment="BIND_ADDR=0.0.0.0"
ExecStart=/opt/protohacker/protohacker0-smoketest
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s
EOF

systemctl daemon-reload
systemctl start protohacker0-smoketest