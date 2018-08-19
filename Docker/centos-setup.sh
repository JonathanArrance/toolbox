#!/bin/bash
sudo yum install -y epel-release
sudo yum install -y git
sudo yum install -y easy_install
sudo easy_install pip
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce
sudo systemctl start docker
sudo systemctl enable docker
sudo service docker start
