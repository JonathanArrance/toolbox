#!/bin/bash

#exit if a command fails
set -e

PXE_INTERFACE='enp0s3'
IP='192.168.56.2'
MASK='255.255.255.0'

#get the interface IP
FOUNDIP=`ip addr show $PXE_INTERFACE | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`

#Dhcp range will need to be the same as the pxe interface
#EX. Allocate .100 - .110 for 4h period
DHCP_RANGE='192.168.56.100,192.168.56.110,4h'

#Name of the centOS iso image
ISO='CentOS-7-x86_64-Minimal-1804.iso'

#make sure you are root
if [ "$EUID" -ne 0 ];
  then echo "Please run as root"
  exit 1
fi

if [ -f ~/pxe_setup ];
  then echo "The pxe is already setup. Use the cleanup and setup scripts."
  exit 1
fi

echo 'Checking if PXE interface exists.'
if [ ! -f /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE ];
  then echo "The PXE interface does not exist."
  exit 1
fi

if [ grep -q "static" /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE ]; then
    if [ $IP != $FOUNDIP ]; then
        echo "The static ip found does not match the given ip, setting ip address to $IP."
        sed -i -e 's/IPADDR\=$FOUNDIP/IPADDR=$IP/' /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
    else
        echo "The static ip is already set."
    fi
else
    echo "The interface is set to DHCP, the pxe interface should be statically assigned for reliability."
    echo "Setting the PXE interface to static ip $IP."
    sed -i -e 's/BOOTPROTO\="dhcp"/BOOTPROTO\="static"/' /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
    echo "IPADDR=$IP" >> /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
    echo "NETMASK=$MASK" >> /etc/sysconfig/network-scripts/ifcfg-$PXE_INTERFACE
fi

#check if the iso is available
if [ ! -f ~/$ISO ];
  then echo "The iso file does not exist."
  exit 1
fi

echo 'Disableing the firewall.'
systemctl disable firewalld || { echo "Could not disable the firewall."; exit 1; }
systemctl stop firewalld || { echo "Could not stop the firewall service."; exit 1; }

echo 'Disableing SElinux.'
sed -i -e 's/SELINUX=enforceing/SELINUX=disabled/g' /etc/sysconfig/selinux || { echo "Could not disable the SELINUX service."; exit 1; }

#update CentOS7
echo 'Getting latest updates for CentOS 7'
yum -y update || { echo "Could not update CentOS 7 to the latest updates."; exit 1; }

#install the packages needed
echo 'Installing CentOS 7 base packages.'
yum install -y vsftpd tftp-server epel-release net-tools wget || { echo "Could not download neccessary packages."; exit 1; }

echo 'Installing syslinux pxe boot server.'
yum install -y syslinux || { echo "Could not download syslinux."; exit 1; }

mkdir -p /opt/isorepo
mkdir -p /mnt/cent7
mv ~/$ISO /opt/isorepo/$ISO
echo 'Automounting the CentOS 7 install iso.'
mount /opt/isorepo/$ISO /mnt/cent7 || { echo "Mounting CentOS 7 ISO."; exit 1; }
#echo "mount /opt/isorepo/$ISO /mnt/cent7" >> /etc/rc.local
cp -rf /mnt/cent7/* /var/ftp/pub/ || { echo "Copying all CentOS 7 files to ftp directory."; exit 1; }


echo 'Installing dnsmasq for dhcp and tftpboot services.'
yum install -y dnsmasq || { echo "Could not download dnsmasq."; exit 1; }

echo 'Configureing dnsmaq dhcp and tftpboot.'
mkdir -p /opt/openhci || { echo "Could not create /opt/openhci"; exit 1; }
chmod 777 /opt/openhci || { echo "Could change permissions on /opt/openhci"; exit 1; }
mkdir -p /opt/openhci/pxelinux.cfg || { echo "Could not create /opt/openhci/pxelinux.cfg"; exit 1; }
mkdir -p /opt/openhci/redhat-installer/cent-7 || { echo "Could not create /opt/openhci/redhat-installer/cent-7"; exit 1; }
cp /mnt/cent7/images/pxeboot/* /opt/openhci/redhat-installer/cent-7/ || { echo "Could not copy micro kernel to cent7 directory."; exit 1; }
umount /mnt/cent7

mkdir -p /var/ftp/pub/ksfiles || { echo "Could not create /var/ftp/pub/ksfiles"; exit 1; }
cp -rf ./computenode /var/ftp/pub/ksfiles || { echo "Could not copy compute node files to /var/ftp/pub/ksfiles"; exit 1; }
cp -rf ./corenode /var/ftp/pub/ksfiles || { echo "Could not copy core node files to /var/ftp/pub/ksfiles"; exit 1; }
cp -rf ./storagenode /var/ftp/pub/ksfiles || { echo "Could not copy storage node files to /var/ftp/pub/ksfiles"; exit 1; }

echo 'Adding the pxeboot files to the tftp directory.'
#cp -rf /usr/share/syslinux/* /opt/openhci
cp -v /usr/share/syslinux/pxelinux.0 /opt/openhci
cp -v /usr/share/syslinux/mboot.c32 /opt/openhci
cp -v /usr/share/syslinux/menu.c32 /opt/openhci
cp -v /usr/share/syslinux/memdisk /opt/openhci
cp -v /usr/share/syslinux/chain.c32 /opt/openhci
cp -v /usr/share/syslinux/vesamenu.c32 /opt/openhci

#need to build the ks files for the 
echo 'Creating the default boot file.'
cat > /opt/openhci/pxelinux.cfg/default <<EOF
default menu.c32
prompt 0
timeput 60
ONTIMEOUT BootLocal

label BootLocal
      menu label ^Local OS boot
      menu default
      localboot 0
      
label CentOS7-1804
        menu label ^CentOS7-1804 install
        menu CentOS7
        kernel /redhat-installer/cent-7/vmlinuz
        append method=ftp://$IP/pub vga=788 auto=true priority=critical initrd=redhat-installer/cent-7/initrd.img

label CoreNode
        menu label ^CoreNode install
        menu Core-vBeta
        kernel /cent7/vmlinuz
        append inst.ks=ftp://$IP/pub/corenode/anaconda-ks.cfg ksdevice=link vga=788 auto=true priority=critical initrd=redhat-installer/cent-7/initrd.img

label ComputeNode
        menu label ^ComputeNode install
        menu Compute-vBeta
        kernel /cent7/vmlinuz
        append inst.ks=ftp://$IP/pub/computenode/anaconda-ks.cfg ksdevice=link vga=788 auto=true priority=critical initrd=redhat-installer/cent-7/initrd.img

label StorageNode
        menu label ^StorageNode install
        menu Storage-vBeta
        kernel /cent7/vmlinuz
        append inst.ks=ftp://$IP/pub/storagenode/anaconda-ks.cfg ksdevice=link vga=788 auto=true priority=critical initrd=redhat-installer/cent-7/initrd.img
EOF

echo 'Configureing dnsmasq.'
sed -i -e "s/\#interface=/interface=${PXE_INTERFACE}/g" /etc/dnsmasq.conf || { echo "Could not set pxe boot interface."; exit 1; }
sed -i -e 's/\#dhcp-boot\=pxelinux.0/dhcp-boot\=pxelinux.0/g' /etc/dnsmasq.conf || { echo "Could not set pxeboot file."; exit 1; }
sed -i -e 's/\#enable-tftp/enable-tftp/g' /etc/dnsmasq.conf || { echo "Could not enable tftp in dnsmasq."; exit 1; }
sed -i -e 's/\#tftp-root\=\/var\/ftpd/tftp-root\=\/opt\/openhci/g' /etc/dnsmasq.conf || { echo "Could not set the tftp root"; exit 1; }
echo "dhcp-range=$DHCP_RANGE" >> /etc/dnsmasq.conf || { echo "Could not set the dhcp range."; exit 1; }

echo 'Starting the dnsmasq service.'
service dnsmasq start || { echo "Could not start the dnsmasq dhcp/tftpboot server."; exit 1; }
chkconfig dnsmasq on || { echo "Could not enable the dhcp/tftpboot server."; exit 1; }
systemctl start vsftpd || { echo "Could not start the ftp server."; exit 1; }
systemctl enable vsftpd || { echo "Could not enable the ftp server."; exit 1; }
#create a dummy pxe setup file if the script completes
touch ~/pxe_setup

echo "The PXE install server is set up and ready to set up OpenHCI."
echo "Please reboot the server before setting up your first OpenHCI system."