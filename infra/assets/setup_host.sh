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

aws s3 cp s3://protohacker-solutions/dl_new_bin.sh /opt/protohacker/dl_new_bin.sh
chmod +x /opt/protohacker/dl_new_bin.sh
chown protohackers:protohackers /opt/protohacker/dl_new_bin.sh
./dl_new_bin.sh 0

aws s3 cp s3://protohacker-solutions/protohacker0.service /etc/systemd/system/protohacker0.service
systemctl daemon-reload
systemctl start protohacker0
