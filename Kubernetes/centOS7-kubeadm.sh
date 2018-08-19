#!/bin/bash -x

MASTER_NODE_NAME='fabric8'

#disable the selinux and config the firewall
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

#disable swap since kubadm does not want it
swapoff -a

#make sure the firewall is on
systemctl enable firewalld
systemctl start firewalld

#firewall
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp
firewall-cmd --reload
modprobe br_netfilter
#echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

#get rid of any pre-exisiting versionof docker
yum remove -y docker docker-common container-selinux docker-selinux docker-engine

#add in some docker helpers
yum install -y yum-utils device-mapper-persistent-data lvm2

#add the stable docker CE repo
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum makecache -y fast

#install docker
yum install -y docker-ce-17.12.0.ce-1.el7.centos

#add the kube repo
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum update -y

yum install kubeadm -y

#enable services
systemctl restart docker && systemctl enable docker
systemctl  restart kubelet && systemctl enable kubelet

#HACK to workaround bug on Redhat based OS
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables

#change the croup driver in kubernetes
sed s/systemd/cgroupfs/g /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload

kubeadm init
