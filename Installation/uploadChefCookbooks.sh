#!/bin/bash
#uploadChefCookboks
# Created on: May 25, 2014
#     Author: eozekes

source ./common.sh
export COOKBOOK_DIR=/opt/cookbooks/chef-cookbooks/cookbooks

#select only tr and en
dpkg-reconfigure locales

echo "************ Chef cookbooks are going to be installed *****************"
if [ ! -d /opt/cookbooks/chef-cookbooks ];then
	mkdir -p /opt/cookbooks
	cd /opt/cookbooks

	git clone --recursive https://github.com/rcbops/chef-cookbooks.git
	cd chef-cookbooks
	git checkout master
	git submodule init
	git submodule sync
	git submodule update
fi

cd ${COOKBOOK_DIR}

if [ ! -d ${COOKBOOK_DIR}/ark ];then
	git clone https://github.com/fewbytes-cookbooks/ark.git ark
fi
if [ ! -d ${COOKBOOK_DIR}/dmg ];then
	git clone https://github.com/opscode-cookbooks/dmg.git
fi
if [ ! -d ${COOKBOOK_DIR}/chef_handler ];then
	git clone https://github.com/opscode-cookbooks/chef_handler.git
fi
if [ ! -d ${COOKBOOK_DIR}/windows ];then
	git clone https://github.com/opscode-cookbooks/windows.git
fi
if [ ! -d ${COOKBOOK_DIR}/yum ];then
	git clone https://github.com/opscode-cookbooks/yum.git
	#git checkout tags/v2.4.4
fi
if [ ! -d ${COOKBOOK_DIR}/yum-epel ];then
	git clone https://github.com/opscode-cookbooks/yum-epel.git
fi
if [ ! -d ${COOKBOOK_DIR}/git ];then
	git clone https://github.com/jssjr/git.git git
	#git checkout foodcritic
fi
if [ ! -d ${COOKBOOK_DIR}/bluepill ];then
	git clone https://github.com/opscode-cookbooks/bluepill.git
fi
if [ ! -d ${COOKBOOK_DIR}/build-essential ];then
	git clone https://github.com/opscode-cookbooks/build-essential.git
fi
if [ ! -d ${COOKBOOK_DIR}/vim ];then
	git clone https://github.com/opscode-cookbooks/vim.git
fi
	if [ ! -d ${COOKBOOK_DIR}/ohai ];then
	git clone https://github.com/opscode-cookbooks/ohai.git
fi
if [ ! -d ${COOKBOOK_DIR}/nginx ];then
	git clone https://github.com/opscode-cookbooks/nginx.git nginx
fi
if [ ! -d ${COOKBOOK_DIR}/ant ];then
	git clone https://github.com/opscode-cookbooks/ant.git
fi
if [ ! -d ${COOKBOOK_DIR}/java ];then
	git clone https://github.com/socrata-cookbooks/java.git
fi
if [ ! -d ${COOKBOOK_DIR}/python ];then
	git clone https://github.com/poise/python.git
fi

cd /opt/cookbooks/chef-cookbooks

knife cookbook upload -o cookbooks/ --all
knife role from file roles/*.rb
knife environment from file environments/*.json
