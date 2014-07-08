#!/bin/bash
#installLogSystem.sh
# Created on: May 24, 2014
#     Author: eozekes

source ./common.sh

if [ $(dpkg -l | grep gem | wc -l) == 0 ];then
echo "****** Packages database is going to be updated ********"
apt-get update

echo "****** Necessary platform packages are going to be be installed ********"
apt-get install -y ruby gem git nasm debhelper dh-make python curl binutils-dev zlib1g-dev \
autotools-dev gnu-efi quilt libssl-dev libreadline-dev libpcre3-dev libncursesw5-dev \
libbz2-dev flex libselinux1-dev po4a pkg-config devscripts alien texinfo autoconf automake \
gettext patch bison m4 libncurses5-dev build-essential nmap ethtool bridge-utils ifenslave-2.6 \
vlan libc6-i386 hwdata ntp ncurses-term btrfs-tools libstdc++5 libtirpc1 nfs-common reprepro \
libsoap-lite-perl libdbi-perl libcurl4-openssl-dev sshpass ssh
fi

cd 
rm .ssh/known_hosts
if [ ! -f .ssh/id_rsa.pub ];then 
	echo "****** Public keys are going to be created ********"
	ssh-keygen -t rsa
fi

if [ ! -f /etc/profile.d/rvm.sh ];then
	echo "****** Necessary ruby packages are going to be installed ********"
	wget https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer && chmod 755 ./rvm-installer && ./rvm-installer master
	source /etc/profile
	rvm install 1.9.3-p448
	rvm install 2.1.2
	rvm use --default 1.9.3-p448
	echo "****** Necessary gem packages are going to be installed ********"
	gem install rails chef json --no-ri --no-rdoc
fi


if [ $(dpkg -l | grep chef-server | wc -l) == 0 ];then
${CURRENT_FOLDER}/chef/installChefServer.sh
${CURRENT_FOLDER}/chef/installChefWorkstation.sh
fi

cat > install_chef_on_client.sh << EOF
gloabal_password=${gloabal_password}
chef_server=${chef_server}
CURRENT_FOLDER=${CURRENT_FOLDER}
apt-get install -y sshpass
cd 
rm .ssh/known_hosts
if [ ! -f .ssh/id_rsa.pub ];then ssh-keygen -t rsa;fi
sshpass -p ${gloabal_password} ssh-copy-id root@${chef_server} -i .ssh/id_rsa.pub
scp root@${chef_server}:${CURRENT_FOLDER}/chef/configureChefClient.sh . && \
scp root@${chef_server}:${CURRENT_FOLDER}/chef/installChefClient.sh . && ./installChefClient.sh -s ${chef_server} 
EOF
chmod 755 ./install_chef_on_client.sh

for client in ${chef_client_list[@]};do
	sshpass -p ${gloabal_password} ssh-copy-id root@${client} -i .ssh/id_rsa.pub
	scp ./install_chef_on_client.sh root@${client}:/root
	ssh root@${client} /root/install_chef_on_client.sh 
done

rm install_chef_on_client.sh

exit 0
