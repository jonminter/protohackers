FROM amazonlinux:latest

RUN yum install -y /usr/sbin/adduser tar gzip unzip sudo
RUN useradd -ms /bin/bash ec2-user

COPY infra/setup_host.sh setup_host.sh
RUN ./setup_host.sh

USER ec2-user
WORKDIR /home/ec2-user