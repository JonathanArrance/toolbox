#!/bin/bash

if [ -f '/etc/redhat-release' ]; then
	sudo yum install -y epel-release
	sudo yum install -y git
	sudo yum install -y easy_install

	sudo easy_install pip

	sudo pip install --upgrade ansible 2>&1
else
	sudo apt-get update -y
	sudo apt-get install software-properties-common -y
	sudo apt-add-repository ppa:ansible/ansible -y
	sudo apt-get update -y
	sudo apt-get install ansible -y
fi
