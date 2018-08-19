#!/bin/bash

if [ -f '/etc/redhat-release' ]; then
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
	sudo docker pull manageiq/manageiq:gaprindashvili-4
	sudo docker run --privileged -d -p 8443:443 manageiq/manageiq:gaprindashvili-4
else
	sudo apt-get update -y
	sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo apt-key fingerprint 0EBFCD88
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get update -y
	sudo apt-get install docker-ce -y
	sudo service docker start
	sudo docker pull manageiq/manageiq:gaprindashvili-4
	sudo docker run --privileged -d -p 8443:443 manageiq/manageiq:gaprindashvili-4
fi
