#!/bin/bash
#installLogSystem.sh
# Created on: May 25, 2014
#     Author: eozekes

source ./common.sh
export COOKBOOK_DIR=/opt/cookbooks/logsystem-cookbooks
source /etc/profile

apt-get install bison zlib1g-dev libopenssl-ruby1.9.1 libssl-dev libyaml-0-2 libxslt-dev \
libxml2-dev libreadline-gplv2-dev libncurses5-dev file ruby1.9.1-dev git --yes --fix-missing

apt-get install -y build-essential openssl libreadline6 libreadline6-dev \
curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 \
libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison  \
subversion

#This is necessary for the installation of the cookbooks on debian platform.  
cat > ./install_upstart_on_debian.sh << EOF
cat /etc/*release | grep "Debian" > /dev/null
if [ $? == 0 ]; then
	echo "--------------- Upstart is going to be installed on DEBIAN platform!!!!! --------"
	apt-get -o DPkg::options=--force-remove-essential -y --force-yes install upstart
fi
EOF
chmod 755 ./install_upstart_on_debian.sh

for client in ${chef_client_list[@]};do
	scp ./install_upstart_on_debian.sh root@${client}:/root/install_upstart_on_debian.sh
	ssh root@${client} /root/install_upstart_on_debian.sh 
done
rm ./install_upstart_on_debian.sh

gem install bundler
gem install berkshelf --version 3.1.2 --no-rdoc --no-ri
gem update berkshelf

if [ ! -d ${COOKBOOK_DIR} ];then
	mkdir -p ${COOKBOOK_DIR}
fi

cd ${COOKBOOK_DIR}

if [ ! -d ${COOKBOOK_DIR}/rbenv ];then
	git clone https://github.com/RiotGames/rbenv-cookbook.git rbenv
fi
if [ ! -d ${COOKBOOK_DIR}/elasticsearch ];then
	git clone https://github.com/elasticsearch/cookbook-elasticsearch.git elasticsearch
fi
#git clone https://github.com/hw-cookbooks/graphite.git graphite
if [ ! -d ${COOKBOOK_DIR}/kibana ];then
	git clone https://github.com/lusis/chef-kibana.git kibana
fi
if [ ! -d ${COOKBOOK_DIR}/logstash ];then
	git clone https://github.com/lusis/chef-logstash.git logstash
fi
if [ ! -d ${COOKBOOK_DIR}/ganglia ];then
	git clone https://github.com/ganglia/chef-ganglia.git ganglia
fi
if [ ! -d ${COOKBOOK_DIR}/site24x7 ];then
	git clone https://github.com/site24x7/chef-site24x7.git site24x7
fi
			
# please give at least GB ram to os before continue
# please add lines below before "require 'active_support/core_ext'" in the /usr/local/rvm/gems/ruby-1.9.3-p448/gems/berkshelf-1.2.1/lib/berkshelf.rb 
# require 'active_support'
# require 'active_support/deprecation'
if [ -d ${COOKBOOK_DIR}/rbenv ];then
	cd ${COOKBOOK_DIR}/rbenv
	cat > Berksfile << EOF
site :opscode

metadata

cookbook 'git', git: 'git://github.com/jssjr/git.git'
cookbook 'dmg', git: 'git://github.com/opscode-cookbooks/dmg.git'
cookbook 'chef_handler', git: 'git://github.com/opscode-cookbooks/chef_handler.git'

cookbook 'apt', git: 'git://github.com/opscode-cookbooks/apt.git'
cookbook 'runit', git: 'git://github.com/hw-cookbooks/runit.git'
cookbook 'windows', git: 'git://github.com/opscode-cookbooks/windows.git'
cookbook 'ohai', git: 'git://github.com/opscode-cookbooks/ohai.git'
cookbook 'build-essential', git: 'git://github.com/opscode-cookbooks/build-essential.git'
cookbook 'yum', git: 'git://github.com/opscode-cookbooks/yum.git'
cookbook 'yum-epel', git: 'git://github.com/opscode-cookbooks/yum-epel.git'


group :test do
  cookbook 'fake', :path => 'test/fixtures/cookbooks/fake'
end
EOF
fi

if [ -d ${COOKBOOK_DIR}/elasticsearch ];then
	cd ${COOKBOOK_DIR}/elasticsearch
	cat > Gemfile << EOF
source 'https://rubygems.org'

gem 'pry'
gem 'chef'
gem 'vagrant', '1.0.7'
gem 'berkshelf', '3.1.2'

gem 'faraday', '0.9.0' # Prevent RiotGames/ridley#239
EOF
	cat > Berksfile << EOF
source 'https://api.berkshelf.com'
metadata

cookbook 'apt', git: 'git://github.com/opscode-cookbooks/apt.git'
cookbook 'build-essential', git: 'git://github.com/opscode-cookbooks/build-essential.git'
cookbook 'chef_handler', git: 'git://github.com/opscode-cookbooks/chef_handler.git'
cookbook 'yum', git: 'git://github.com/opscode-cookbooks/yum.git', ref: 'v2.4.4'

cookbook 'ark',  git: 'git://github.com/opscode-cookbooks/ark.git', ref: '0.2.4'
cookbook 'java', git: 'git://github.com/opscode-cookbooks/java.git'

cookbook 'monit', git: 'git://github.com/apsoto/monit.git'

cookbook 'xml', git: 'git://github.com/opscode-cookbooks/xml.git'
cookbook 'vim', git: 'git://github.com/opscode-cookbooks/vim.git'
cookbook 'minitest-handler', git: 'git://github.com/btm/minitest-handler-cookbook.git'
EOF
fi

cd ${COOKBOOK_DIR}/..
if [ ! -d ./roles ];then 
	mkdir -p roles
fi
cat	> roles/elasticsearch_server.json << EOF
{
   "name": "elasticsearch_server",
   "default_attributes": {
   },
   "json_class": "Chef::Role",
   "run_list": [
        "recipe[java]",
        "recipe[elasticsearch]"
   ],
   "description": "",
   "chef_type": "role",
   "override_attributes": {
         "java": {
             "install_flavor": "openjdk",
             "jdk_version": "7"
         },
     "elasticsearch": {
         "cluster_name" : "logstash",
         "bootstrap.mlockall" : false
     }
   }
}
EOF
cat > roles/logstash_server.json << EOF
{
  "name": "logstash_server",
  "default_attributes": {},
  "json_class": "Chef::Role",
  "run_list": [
    "recipe[logstash::server]",
    "recipe[kibana]"
  ],
  "description": "",
  "chef_type": "role",
  "override_attributes": {
    "rabbitmq": {
        "mgmt_console": true
    },
    "logstash": {
      "install_rabbitmq": true,
      "server": {
        "enable_embedded_es": false,
        "inputs": [ {
          "rabbitmq": {
            "type": "direct",
            "host": "127.0.0.1",
            "user": "admin",
            "password": "calven",
            "exchange": "logstash-exchange",
            "key": "logstash-key",
            "exclusive": false,
            "durable": false,
            "auto_delete": false
         },
         "ganglia": {
        	"host": "0.0.0.0",
        	"port": 1974,
    		"type": "ganglia"
         },
         "exec": {
            "command" : "curl http://10.210.10.5:8080/_stats",
            "interval" : 5,
            "tags" : ["ats_stats_webCache"],
            "type" : "ats_stats"
         },
         "exec": {
            "command" : "curl http://10.210.10.4:8080/_stats",
            "interval" : 5,
            "tags" : ["ats_stats_streamServ"],
            "type" : "ats_stats"
         }
        } ],
        "filters": [ {
			"json": {
				"type": "ats_stats",
				"source": "message",
			    "target": "ats-stat",
			    "add_field": { 
	                "proxy.process.http.completed_requests":"ats-stat.global.proxy.process.http.%{completed_requests}",
	                "proxy.process.http.total_incoming_connections":"ats-stat.global.proxy.process.http.%{total_incoming_connections}",
	                "proxy.process.http.total_client_connections":"ats-stat.global.proxy.process.http.%{total_client_connections}",
	                "proxy.process.http.total_client_connections_ipv4":"ats-stat.global.proxy.process.http.%{total_client_connections_ipv4}",
	                "proxy.process.http.total_server_connections":"ats-stat.global.proxy.process.http.%{total_server_connections}",
	                "proxy.process.http.total_parent_proxy_connections":"ats-stat.global.proxy.process.http.%{total_parent_proxy_connections}",
	                "proxy.process.http.avg_transactions_per_client_connection":"ats-stat.global.proxy.process.http.%{avg_transactions_per_client_connection}",
	                "proxy.process.http.avg_transactions_per_server_connection":"ats-stat.global.proxy.process.http.%{avg_transactions_per_server_connection}",
	                "proxy.process.http.avg_transactions_per_parent_connection":"ats-stat.global.proxy.process.http.%{avg_transactions_per_parent_connection}",
	                "proxy.process.http.incoming_requests":"ats-stat.global.proxy.process.http.%{incoming_requests}",
	                "proxy.process.http.outgoing_requests":"ats-stat.global.proxy.process.http.%{outgoing_requests}",
	                "proxy.process.http.incoming_responses":"ats-stat.global.proxy.process.http.%{incoming_responses}",
	                "proxy.process.http.invalid_client_requests":"ats-stat.global.proxy.process.http.%{invalid_client_requests}",
	                "proxy.process.http.missing_host_hdr":"ats-stat.global.proxy.process.http.%{missing_host_hdr}",
	                "proxy.process.http.get_requests":"ats-stat.global.proxy.process.http.%{get_requests}",
	                "proxy.process.http.head_requests":"ats-stat.global.proxy.process.http.%{head_requests}",
	                "proxy.process.http.trace_requests":"ats-stat.global.proxy.process.http.%{trace_requests}",
	                "proxy.process.http.options_requests":"ats-stat.global.proxy.process.http.%{options_requests}",
	                "proxy.process.http.post_requests":"ats-stat.global.proxy.process.http.%{post_requests}",
	                "proxy.process.http.put_requests":"ats-stat.global.proxy.process.http.%{put_requests}",
	                "proxy.process.http.push_requests":"ats-stat.global.proxy.process.http.%{push_requests}",
	                "proxy.process.http.delete_requests":"ats-stat.global.proxy.process.http.%{delete_requests}",
	                "proxy.process.http.purge_requests":"ats-stat.global.proxy.process.http.%{purge_requests}",
	                "proxy.process.http.connect_requests":"ats-stat.global.proxy.process.http.%{connect_requests}",
	                "proxy.process.http.extension_method_requests":"ats-stat.global.proxy.process.http.%{extension_method_requests}",
	                "proxy.process.http.client_no_cache_requests":"ats-stat.global.proxy.process.http.%{client_no_cache_requests}",
	                "proxy.process.http.broken_server_connections":"ats-stat.global.proxy.process.http.%{broken_server_connections}",
	                "proxy.process.http.cache_lookups":"ats-stat.global.proxy.process.http.%{cache_lookups}",
	                "proxy.process.http.cache_writes":"ats-stat.global.proxy.process.http.%{cache_writes}",
	                "proxy.process.http.cache_updates":"ats-stat.global.proxy.process.http.%{cache_updates}",
	                "proxy.process.http.cache_deletes":"ats-stat.global.proxy.process.http.%{cache_deletes}",
	                "proxy.process.http.tunnels":"ats-stat.global.proxy.process.http.%{tunnels}",
	                "proxy.process.http.client_transaction_time":"ats-stat.global.proxy.process.http.%{client_transaction_time}",
	                "proxy.process.http.client_write_time":"ats-stat.global.proxy.process.http.%{client_write_time}",
	                "proxy.process.http.server_read_time":"ats-stat.global.proxy.process.http.%{server_read_time}",
	                "proxy.process.http.icp_transaction_time":"ats-stat.global.proxy.process.http.%{icp_transaction_time}",
	                "proxy.process.http.icp_raw_transaction_time":"ats-stat.global.proxy.process.http.%{icp_raw_transaction_time}",
	                "proxy.process.http.parent_proxy_transaction_time":"ats-stat.global.proxy.process.http.%{parent_proxy_transaction_time}",
	                "proxy.process.http.parent_proxy_raw_transaction_time":"ats-stat.global.proxy.process.http.%{parent_proxy_raw_transaction_time}",
	                "proxy.process.http.server_transaction_time":"ats-stat.global.proxy.process.http.%{server_transaction_time}",
	                "proxy.process.http.server_raw_transaction_time":"ats-stat.global.proxy.process.http.%{server_raw_transaction_time}",
	                "proxy.process.http.user_agent_request_header_total_size":"ats-stat.global.proxy.process.http.%{user_agent_request_header_total_size}",
	                "proxy.process.http.user_agent_response_header_total_size":"ats-stat.global.proxy.process.http.%{user_agent_response_header_total_size}",
	                "proxy.process.http.user_agent_request_document_total_size":"ats-stat.global.proxy.process.http.%{user_agent_request_document_total_size}",
	                "proxy.process.http.user_agent_response_document_total_size":"ats-stat.global.proxy.process.http.%{user_agent_response_document_total_size}",
	                "proxy.process.http.origin_server_request_header_total_size":"ats-stat.global.proxy.process.http.%{origin_server_request_header_total_size}",
	                "proxy.process.http.origin_server_response_header_total_size":"ats-stat.global.proxy.process.http.%{origin_server_response_header_total_size}",
	                "proxy.process.http.origin_server_request_document_total_size":"ats-stat.global.proxy.process.http.%{origin_server_request_document_total_size}",
	                "proxy.process.http.origin_server_response_document_total_size":"ats-stat.global.proxy.process.http.%{origin_server_response_document_total_size}",
	                "proxy.process.http.parent_proxy_request_total_bytes":"ats-stat.global.proxy.process.http.%{parent_proxy_request_total_bytes}",
	                "proxy.process.http.parent_proxy_response_total_bytes":"ats-stat.global.proxy.process.http.%{parent_proxy_response_total_bytes}",
	                "proxy.process.http.pushed_response_header_total_size":"ats-stat.global.proxy.process.http.%{pushed_response_header_total_size}",
	                "proxy.process.http.pushed_document_total_size":"ats-stat.global.proxy.process.http.%{pushed_document_total_size}",
	                "proxy.process.http.total_transactions_time":"ats-stat.global.proxy.process.http.%{total_transactions_time}",
	                "proxy.process.http.total_transactions_think_time":"ats-stat.global.proxy.process.http.%{total_transactions_think_time}",
	                "proxy.process.http.cache_hit_fresh":"ats-stat.global.proxy.process.http.%{cache_hit_fresh}",
	                "proxy.process.http.cache_hit_mem_fresh":"ats-stat.global.proxy.process.http.%{cache_hit_mem_fresh}",
	                "proxy.process.http.cache_hit_revalidated":"ats-stat.global.proxy.process.http.%{cache_hit_revalidated}",
	                "proxy.process.http.cache_hit_ims":"ats-stat.global.proxy.process.http.%{cache_hit_ims}",
	                "proxy.process.http.cache_hit_stale_served":"ats-stat.global.proxy.process.http.%{cache_hit_stale_served}",
	                "proxy.process.http.cache_miss_cold":"ats-stat.global.proxy.process.http.%{cache_miss_cold}",
	                "proxy.process.http.cache_miss_changed":"ats-stat.global.proxy.process.http.%{cache_miss_changed}",
	                "proxy.process.http.cache_miss_client_no_cache":"ats-stat.global.proxy.process.http.%{cache_miss_client_no_cache}",
	                "proxy.process.http.cache_miss_client_not_cacheable":"ats-stat.global.proxy.process.http.%{cache_miss_client_not_cacheable}",
	                "proxy.process.http.cache_miss_ims":"ats-stat.global.proxy.process.http.%{cache_miss_ims}",
	                "proxy.process.http.cache_read_error":"ats-stat.global.proxy.process.http.%{cache_read_error}",
	                "proxy.process.http.tcp_hit_count_stat":"ats-stat.global.proxy.process.http.%{tcp_hit_count_stat}",
	                "proxy.process.http.tcp_hit_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_hit_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_hit_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_hit_origin_server_bytes_stat}",
	                "proxy.process.http.tcp_miss_count_stat":"ats-stat.global.proxy.process.http.%{tcp_miss_count_stat}",
	                "proxy.process.http.tcp_miss_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_miss_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_miss_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_miss_origin_server_bytes_stat}",
	                "proxy.process.http.tcp_expired_miss_count_stat":"ats-stat.global.proxy.process.http.%{tcp_expired_miss_count_stat}",
	                "proxy.process.http.tcp_expired_miss_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_expired_miss_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_expired_miss_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_expired_miss_origin_server_bytes_stat}",
	                "proxy.process.http.tcp_refresh_hit_count_stat":"ats-stat.global.proxy.process.http.%{tcp_refresh_hit_count_stat}",
	                "proxy.process.http.tcp_refresh_hit_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_refresh_hit_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_refresh_hit_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_refresh_hit_origin_server_bytes_stat}",
	                "proxy.process.http.tcp_refresh_miss_count_stat":"ats-stat.global.proxy.process.http.%{tcp_refresh_miss_count_stat}",
	                "proxy.process.http.tcp_refresh_miss_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_refresh_miss_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_refresh_miss_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_refresh_miss_origin_server_bytes_stat}",
	                "proxy.process.http.tcp_client_refresh_count_stat":"ats-stat.global.proxy.process.http.%{tcp_client_refresh_count_stat}",
	                "proxy.process.http.tcp_client_refresh_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_client_refresh_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_client_refresh_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_client_refresh_origin_server_bytes_stat}",
	                "proxy.process.http.tcp_ims_hit_count_stat":"ats-stat.global.proxy.process.http.%{tcp_ims_hit_count_stat}",
	                "proxy.process.http.tcp_ims_hit_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_ims_hit_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_ims_hit_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_ims_hit_origin_server_bytes_stat}",
	                "proxy.process.http.tcp_ims_miss_count_stat":"ats-stat.global.proxy.process.http.%{tcp_ims_miss_count_stat}",
	                "proxy.process.http.tcp_ims_miss_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_ims_miss_user_agent_bytes_stat}",
	                "proxy.process.http.tcp_ims_miss_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{tcp_ims_miss_origin_server_bytes_stat}",
	                "proxy.process.http.err_client_abort_count_stat":"ats-stat.global.proxy.process.http.%{err_client_abort_count_stat}",
	                "proxy.process.http.err_client_abort_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{err_client_abort_user_agent_bytes_stat}",
	                "proxy.process.http.err_client_abort_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{err_client_abort_origin_server_bytes_stat}",
	                "proxy.process.http.err_connect_fail_count_stat":"ats-stat.global.proxy.process.http.%{err_connect_fail_count_stat}",
	                "proxy.process.http.err_connect_fail_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{err_connect_fail_user_agent_bytes_stat}",
	                "proxy.process.http.err_connect_fail_origin_server_bytes_stat":"ats-stat.global.proxy.process.http.%{err_connect_fail_origin_server_bytes_stat}",
	                "proxy.process.http.misc_count_stat":"ats-stat.global.proxy.process.http.%{misc_count_stat}",
	                "proxy.process.http.misc_user_agent_bytes_stat":"ats-stat.global.proxy.process.http.%{misc_user_agent_bytes_stat}",
	                "proxy.process.http.background_fill_bytes_aborted_stat":"ats-stat.global.proxy.process.http.%{background_fill_bytes_aborted_stat}",
	                "proxy.process.http.background_fill_bytes_completed_stat":"ats-stat.global.proxy.process.http.%{background_fill_bytes_completed_stat}",
	                "proxy.process.http.cache_write_errors":"ats-stat.global.proxy.process.http.%{cache_write_errors}",
	                "proxy.process.http.cache_read_errors":"ats-stat.global.proxy.process.http.%{cache_read_errors}",
	                "proxy.process.http.100_responses":"ats-stat.global.proxy.process.http.%{100_responses}",
	                "proxy.process.http.101_responses":"ats-stat.global.proxy.process.http.%{101_responses}",
	                "proxy.process.http.1xx_responses":"ats-stat.global.proxy.process.http.%{1xx_responses}",
	                "proxy.process.http.200_responses":"ats-stat.global.proxy.process.http.%{200_responses}",
	                "proxy.process.http.201_responses":"ats-stat.global.proxy.process.http.%{201_responses}",
	                "proxy.process.http.202_responses":"ats-stat.global.proxy.process.http.%{202_responses}",
	                "proxy.process.http.203_responses":"ats-stat.global.proxy.process.http.%{203_responses}",
	                "proxy.process.http.204_responses":"ats-stat.global.proxy.process.http.%{204_responses}",
	                "proxy.process.http.205_responses":"ats-stat.global.proxy.process.http.%{205_responses}",
	                "proxy.process.http.206_responses":"ats-stat.global.proxy.process.http.%{206_responses}",
	                "proxy.process.http.2xx_responses":"ats-stat.global.proxy.process.http.%{2xx_responses}",
	                "proxy.process.http.300_responses":"ats-stat.global.proxy.process.http.%{300_responses}",
	                "proxy.process.http.301_responses":"ats-stat.global.proxy.process.http.%{301_responses}",
	                "proxy.process.http.302_responses":"ats-stat.global.proxy.process.http.%{302_responses}",
	                "proxy.process.http.303_responses":"ats-stat.global.proxy.process.http.%{303_responses}",
	                "proxy.process.http.304_responses":"ats-stat.global.proxy.process.http.%{304_responses}",
	                "proxy.process.http.305_responses":"ats-stat.global.proxy.process.http.%{305_responses}",
	                "proxy.process.http.307_responses":"ats-stat.global.proxy.process.http.%{307_responses}",
	                "proxy.process.http.3xx_responses":"ats-stat.global.proxy.process.http.%{3xx_responses}",
	                "proxy.process.http.400_responses":"ats-stat.global.proxy.process.http.%{400_responses}",
	                "proxy.process.http.401_responses":"ats-stat.global.proxy.process.http.%{401_responses}",
	                "proxy.process.http.402_responses":"ats-stat.global.proxy.process.http.%{402_responses}",
	                "proxy.process.http.403_responses":"ats-stat.global.proxy.process.http.%{403_responses}",
	                "proxy.process.http.404_responses":"ats-stat.global.proxy.process.http.%{404_responses}",
	                "proxy.process.http.405_responses":"ats-stat.global.proxy.process.http.%{405_responses}",
	                "proxy.process.http.406_responses":"ats-stat.global.proxy.process.http.%{406_responses}",
	                "proxy.process.http.407_responses":"ats-stat.global.proxy.process.http.%{407_responses}",
	                "proxy.process.http.408_responses":"ats-stat.global.proxy.process.http.%{408_responses}",
	                "proxy.process.http.409_responses":"ats-stat.global.proxy.process.http.%{409_responses}",
	                "proxy.process.http.410_responses":"ats-stat.global.proxy.process.http.%{410_responses}",
	                "proxy.process.http.411_responses":"ats-stat.global.proxy.process.http.%{411_responses}",
	                "proxy.process.http.412_responses":"ats-stat.global.proxy.process.http.%{412_responses}",
	                "proxy.process.http.413_responses":"ats-stat.global.proxy.process.http.%{413_responses}",
	                "proxy.process.http.414_responses":"ats-stat.global.proxy.process.http.%{414_responses}",
	                "proxy.process.http.415_responses":"ats-stat.global.proxy.process.http.%{415_responses}",
	                "proxy.process.http.416_responses":"ats-stat.global.proxy.process.http.%{416_responses}",
	                "proxy.process.http.4xx_responses":"ats-stat.global.proxy.process.http.%{4xx_responses}",
	                "proxy.process.http.500_responses":"ats-stat.global.proxy.process.http.%{500_responses}",
	                "proxy.process.http.501_responses":"ats-stat.global.proxy.process.http.%{501_responses}",
	                "proxy.process.http.502_responses":"ats-stat.global.proxy.process.http.%{502_responses}",
	                "proxy.process.http.503_responses":"ats-stat.global.proxy.process.http.%{503_responses}",
	                "proxy.process.http.504_responses":"ats-stat.global.proxy.process.http.%{504_responses}",
	                "proxy.process.http.505_responses":"ats-stat.global.proxy.process.http.%{505_responses}",
	                "proxy.process.http.5xx_responses":"ats-stat.global.proxy.process.http.%{5xx_responses}",
	                "proxy.process.http.transaction_counts.hit_fresh":"ats-stat.global.proxy.process.http.%{transaction_counts.hit_fresh}",
	                "proxy.process.http.transaction_totaltime.hit_fresh":"ats-stat.global.proxy.process.http.%{transaction_totaltime.hit_fresh}",
	                "proxy.process.http.transaction_counts.hit_fresh.process":"ats-stat.global.proxy.process.http.%{transaction_counts.hit_fresh.process}",
	                "proxy.process.http.transaction_totaltime.hit_fresh.process":"ats-stat.global.proxy.process.http.%{transaction_totaltime.hit_fresh.process}",
	                "proxy.process.http.transaction_counts.hit_revalidated":"ats-stat.global.proxy.process.http.%{transaction_counts.hit_revalidated}",
	                "proxy.process.http.transaction_totaltime.hit_revalidated":"ats-stat.global.proxy.process.http.%{transaction_totaltime.hit_revalidated}",
	                "proxy.process.http.transaction_counts.miss_cold":"ats-stat.global.proxy.process.http.%{transaction_counts.miss_cold}",
	                "proxy.process.http.transaction_totaltime.miss_cold":"ats-stat.global.proxy.process.http.%{transaction_totaltime.miss_cold}",
	                "proxy.process.http.transaction_counts.miss_not_cacheable":"ats-stat.global.proxy.process.http.%{transaction_counts.miss_not_cacheable}",
	                "proxy.process.http.transaction_totaltime.miss_not_cacheable":"ats-stat.global.proxy.process.http.%{transaction_totaltime.miss_not_cacheable}",
	                "proxy.process.http.transaction_counts.miss_changed":"ats-stat.global.proxy.process.http.%{transaction_counts.miss_changed}",
	                "proxy.process.http.transaction_totaltime.miss_changed":"ats-stat.global.proxy.process.http.%{transaction_totaltime.miss_changed}",
	                "proxy.process.http.transaction_counts.miss_client_no_cache":"ats-stat.global.proxy.process.http.%{transaction_counts.miss_client_no_cache}",
	                "proxy.process.http.transaction_totaltime.miss_client_no_cache":"ats-stat.global.proxy.process.http.%{transaction_totaltime.miss_client_no_cache}",
	                "proxy.process.http.transaction_counts.errors.aborts":"ats-stat.global.proxy.process.http.%{transaction_counts.errors.aborts}",
	                "proxy.process.http.transaction_totaltime.errors.aborts":"ats-stat.global.proxy.process.http.%{transaction_totaltime.errors.aborts}",
	                "proxy.process.http.transaction_counts.errors.possible_aborts":"ats-stat.global.proxy.process.http.%{transaction_counts.errors.possible_aborts}",
	                "proxy.process.http.transaction_totaltime.errors.possible_aborts":"ats-stat.global.proxy.process.http.%{transaction_totaltime.errors.possible_aborts}",
	                "proxy.process.http.transaction_counts.errors.connect_failed":"ats-stat.global.proxy.process.http.%{transaction_counts.errors.connect_failed}",
	                "proxy.process.http.transaction_totaltime.errors.connect_failed":"ats-stat.global.proxy.process.http.%{transaction_totaltime.errors.connect_failed}",
	                "proxy.process.http.transaction_counts.errors.other":"ats-stat.global.proxy.process.http.%{transaction_counts.errors.other}",
	                "proxy.process.http.transaction_totaltime.errors.other":"ats-stat.global.proxy.process.http.%{transaction_totaltime.errors.other}",
	                "proxy.process.http.transaction_counts.other.unclassified":"ats-stat.global.proxy.process.http.%{transaction_counts.other.unclassified}",
	                "proxy.process.http.transaction_totaltime.other.unclassified":"ats-stat.global.proxy.process.http.%{transaction_totaltime.other.unclassified}",
	                "proxy.process.http.total_x_redirect_count":"ats-stat.global.proxy.process.http.%{total_x_redirect_count}",
	                "proxy.process.net.net_handler_run":"ats-stat.global.proxy.process.net.%{net_handler_run}",
	                "proxy.process.net.read_bytes":"ats-stat.global.proxy.process.net.%{read_bytes}",
	                "proxy.process.net.write_bytes":"ats-stat.global.proxy.process.net.%{write_bytes}",
	                "proxy.process.net.calls_to_readfromnet":"ats-stat.global.proxy.process.net.%{calls_to_readfromnet}",
	                "proxy.process.net.calls_to_readfromnet_afterpoll":"ats-stat.global.proxy.process.net.%{calls_to_readfromnet_afterpoll}",
	                "proxy.process.net.calls_to_read":"ats-stat.global.proxy.process.net.%{calls_to_read}",
	                "proxy.process.net.calls_to_read_nodata":"ats-stat.global.proxy.process.net.%{calls_to_read_nodata}",
	                "proxy.process.net.calls_to_writetonet":"ats-stat.global.proxy.process.net.%{calls_to_writetonet}",
	                "proxy.process.net.calls_to_writetonet_afterpoll":"ats-stat.global.proxy.process.net.%{calls_to_writetonet_afterpoll}",
	                "proxy.process.net.calls_to_write":"ats-stat.global.proxy.process.net.%{calls_to_write}",
	                "proxy.process.net.calls_to_write_nodata":"ats-stat.global.proxy.process.net.%{calls_to_write_nodata}",
	                "proxy.process.socks.connections_successful":"ats-stat.global.proxy.process.socks.%{connections_successful}",
	                "proxy.process.socks.connections_unsuccessful":"ats-stat.global.proxy.process.socks.%{connections_unsuccessful}",
	                "proxy.process.net.inactivity_cop_lock_acquire_failure":"ats-stat.global.proxy.process.net.%{inactivity_cop_lock_acquire_failure}",
	                "proxy.process.cache.read_per_sec":"ats-stat.global.proxy.process.cache.%{read_per_sec}",
	                "proxy.process.cache.write_per_sec":"ats-stat.global.proxy.process.cache.%{write_per_sec}",
	                "proxy.process.cache.KB_read_per_sec":"ats-stat.global.proxy.process.cache.%{KB_read_per_sec}",
	                "proxy.process.cache.KB_write_per_sec":"ats-stat.global.proxy.process.cache.%{KB_write_per_sec}",
	                "proxy.process.http.background_fill_current_count":"ats-stat.global.proxy.process.http.%{background_fill_current_count}",
	                "proxy.process.http.current_client_connections":"ats-stat.global.proxy.process.http.%{current_client_connections}",
	                "proxy.process.http.current_active_client_connections":"ats-stat.global.proxy.process.http.%{current_active_client_connections}",
	                "proxy.process.http.current_client_transactions":"ats-stat.global.proxy.process.http.%{current_client_transactions}",
	                "proxy.process.http.current_parent_proxy_transactions":"ats-stat.global.proxy.process.http.%{current_parent_proxy_transactions}",
	                "proxy.process.http.current_icp_transactions":"ats-stat.global.proxy.process.http.%{current_icp_transactions}",
	                "proxy.process.http.current_server_transactions":"ats-stat.global.proxy.process.http.%{current_server_transactions}",
	                "proxy.process.http.current_parent_proxy_raw_transactions":"ats-stat.global.proxy.process.http.%{current_parent_proxy_raw_transactions}",
	                "proxy.process.http.current_icp_raw_transactions":"ats-stat.global.proxy.process.http.%{current_icp_raw_transactions}",
	                "proxy.process.http.current_server_raw_transactions":"ats-stat.global.proxy.process.http.%{current_server_raw_transactions}",
	                "proxy.process.http.current_parent_proxy_connections":"ats-stat.global.proxy.process.http.%{current_parent_proxy_connections}",
	                "proxy.process.http.current_server_connections":"ats-stat.global.proxy.process.http.%{current_server_connections}",
	                "proxy.process.http.current_cache_connections":"ats-stat.global.proxy.process.http.%{current_cache_connections}",
	                "proxy.process.net.connections_currently_open":"ats-stat.global.proxy.process.net.%{connections_currently_open}",
	                "proxy.process.net.accepts_currently_open":"ats-stat.global.proxy.process.net.%{accepts_currently_open}",
	                "proxy.process.socks.connections_currently_open":"ats-stat.global.proxy.process.socks.%{connections_currently_open}",
	                "proxy.process.cache.bytes_used":"ats-stat.global.proxy.process.cache.%{bytes_used}",
	                "proxy.process.cache.bytes_total":"ats-stat.global.proxy.process.cache.%{bytes_total}",
	                "proxy.process.cache.ram_cache.total_bytes":"ats-stat.global.proxy.process.cache.%{ram_cache.total_bytes}",
	                "proxy.process.cache.ram_cache.bytes_used":"ats-stat.global.proxy.process.cache.%{ram_cache.bytes_used}",
	                "proxy.process.cache.ram_cache.hits":"ats-stat.global.proxy.process.cache.%{ram_cache.hits}",
	                "proxy.process.cache.ram_cache.misses":"ats-stat.global.proxy.process.cache.%{ram_cache.misses}",
	                "proxy.process.cache.pread_count":"ats-stat.global.proxy.process.cache.%{pread_count}",
	                "proxy.process.cache.percent_full":"ats-stat.global.proxy.process.cache.%{percent_full}",
	                "proxy.process.cache.lookup.active":"ats-stat.global.proxy.process.cache.%{lookup.active}",
	                "proxy.process.cache.lookup.success":"ats-stat.global.proxy.process.cache.%{lookup.success}",
	                "proxy.process.cache.lookup.failure":"ats-stat.global.proxy.process.cache.%{lookup.failure}",
	                "proxy.process.cache.read.active":"ats-stat.global.proxy.process.cache.%{read.active}",
	                "proxy.process.cache.read.success":"ats-stat.global.proxy.process.cache.%{read.success}",
	                "proxy.process.cache.read.failure":"ats-stat.global.proxy.process.cache.%{read.failure}",
	                "proxy.process.cache.write.active":"ats-stat.global.proxy.process.cache.%{write.active}",
	                "proxy.process.cache.write.success":"ats-stat.global.proxy.process.cache.%{write.success}",
	                "proxy.process.cache.write.failure":"ats-stat.global.proxy.process.cache.%{write.failure}",
	                "proxy.process.cache.write.backlog.failure":"ats-stat.global.proxy.process.cache.%{write.backlog.failure}",
	                "proxy.process.cache.update.active":"ats-stat.global.proxy.process.cache.%{update.active}",
	                "proxy.process.cache.update.success":"ats-stat.global.proxy.process.cache.%{update.success}",
	                "proxy.process.cache.update.failure":"ats-stat.global.proxy.process.cache.%{update.failure}",
	                "proxy.process.cache.remove.active":"ats-stat.global.proxy.process.cache.%{remove.active}",
	                "proxy.process.cache.remove.success":"ats-stat.global.proxy.process.cache.%{remove.success}",
	                "proxy.process.cache.remove.failure":"ats-stat.global.proxy.process.cache.%{remove.failure}",
	                "proxy.process.cache.evacuate.active":"ats-stat.global.proxy.process.cache.%{evacuate.active}",
	                "proxy.process.cache.evacuate.success":"ats-stat.global.proxy.process.cache.%{evacuate.success}",
	                "proxy.process.cache.evacuate.failure":"ats-stat.global.proxy.process.cache.%{evacuate.failure}",
	                "proxy.process.cache.scan.active":"ats-stat.global.proxy.process.cache.%{scan.active}",
	                "proxy.process.cache.scan.success":"ats-stat.global.proxy.process.cache.%{scan.success}",
	                "proxy.process.cache.scan.failure":"ats-stat.global.proxy.process.cache.%{scan.failure}",
	                "proxy.process.cache.direntries.total":"ats-stat.global.proxy.process.cache.%{direntries.total}",
	                "proxy.process.cache.direntries.used":"ats-stat.global.proxy.process.cache.%{direntries.used}",
	                "proxy.process.cache.directory_collision":"ats-stat.global.proxy.process.cache.%{directory_collision}",
	                "proxy.process.cache.frags_per_doc.1":"ats-stat.global.proxy.process.cache.%{frags_per_doc.1}",
	                "proxy.process.cache.frags_per_doc.2":"ats-stat.global.proxy.process.cache.%{frags_per_doc.2}",
	                "proxy.process.cache.frags_per_doc.3+":"ats-stat.global.proxy.process.cache.%{frags_per_doc.3+}",
	                "proxy.process.cache.read_busy.success":"ats-stat.global.proxy.process.cache.%{read_busy.success}",
	                "proxy.process.cache.read_busy.failure":"ats-stat.global.proxy.process.cache.%{read_busy.failure}",
	                "proxy.process.cache.write_bytes_stat":"ats-stat.global.proxy.process.cache.%{write_bytes_stat}",
	                "proxy.process.cache.vector_marshals":"ats-stat.global.proxy.process.cache.%{vector_marshals}",
	                "proxy.process.cache.hdr_marshals":"ats-stat.global.proxy.process.cache.%{hdr_marshals}",
	                "proxy.process.cache.hdr_marshal_bytes":"ats-stat.global.proxy.process.cache.%{hdr_marshal_bytes}",
	                "proxy.process.cache.gc_bytes_evacuated":"ats-stat.global.proxy.process.cache.%{gc_bytes_evacuated}",
	                "proxy.process.cache.gc_frags_evacuated":"ats-stat.global.proxy.process.cache.%{gc_frags_evacuated}"
	    		}
			}	
    	 }],
        "outputs": [ {
			{  
				"statsd": {
	        		"increment" : "ats-stat.global.proxy.process.http.%{origin_server_request_document_total_size}"
				} 
			},
			{
				"statsd": {
	        		"increment" : "ats-stat.global.proxy.process.http.%{origin_server_response_document_total_size}"
				}
			},
			{ 
				"statsd": {
	        		"increment" : "ats-stat.global.proxy.process.http.%{user_agent_request_document_total_size}"
				}
			},
			{
				"statsd": {
	        		"increment" : "ats-stat.global.proxy.process.http.%{user_agent_response_document_total_size}"
				}
			},
			{ 
				"statsd": {
	        		"increment" : "ats-stat.global.proxy.process.cache.%{KB_read_per_sec}"
				}
			},
			{
				"statsd": {
	        		"increment" : "ats-stat.global.proxy.process.cache.%{KB_write_per_sec}"
				}
			}]
       }
    }
  }
}
EOF
cat > roles/logstash_client.json << EOF
{
  "name": "logstash_client",
  "default_attributes": {},
  "json_class": "Chef::Role",
  "run_list": [
    "recipe[logstash::beaver]"
  ],
  "description": "",
  "chef_type": "role",
  "override_attributes": {
    "logstash": {
      "beaver": {
        "inputs": [
          {
            "file": {
              "path": [
                "/var/log/*log"
              ],
              "type": "syslog",
              "tags": [
                "sys"
              ]
            }
         },
         {
           "file": {
              "path": [
                "/var/log/trafficserver/*log"
              ],
              "type": "trafficserver",
              "tags": [
                "traffic"
              ]
            }            
         }
        ],
        "outputs": [
          {
            "rabbitmq": {
				"user": "admin",
				"password": "calven",
                "exchange_type": "direct",
                "exchange": "logstash-exchange"
            }
          }
        ]
	 }
    }
  }
}
EOF

cat > roles/ganglia_agent.json << EOF
{
	"name":"ganglia_agent",
	"description":"Installs the gmond to collect metric from host and pushes it to ganglia server",
	"json_class":"Chef::Role",
	"chef_type":"role",
	"run_list":[
		"recipe[ganglia]",
		"recipe[ganglia::aggregator]"
		],
	"default_attributes": {},
	"override_attributes": {
		"ganglia": {
			"server_host": "Ganglia_Monitor"
		}		
	}
}
EOF

cat > roles/ganglia_server.json << EOF
{
	"name":"ganglia_server",
	"description":"Installs the server components of the ganglia",
	"json_class":"Chef::Role",
	"chef_type":"role",
	"run_list":[
		"recipe[ganglia]",
		"recipe[ganglia::aggregator]",
		"recipe[ganglia::gmetad]"
	],
	"default_attributes": {},
	"override_attributes": {
		"ganglia": {
			"unicast": true,
			"grid_name": "Ats_Log_System",
			"enable_rrdcached": false,
			"server_role": "ganglia" 
		}		
	}
}
EOF

for _cookbook in rbenv elasticsearch kibana logstash;do
	if [ -f ${COOKBOOK_DIR}/${_cookbook}/Berksfile ];then
		cd ${COOKBOOK_DIR}/${_cookbook}
		bundle install
		berks install 
		berks vendor 
		if [ -d ./berks-cookbooks ];then knife cookbook upload -o ./berks-cookbooks/ --all; fi
	fi
done	

cd ${COOKBOOK_DIR}

knife role from file ${COOKBOOK_DIR}/../roles/*.json
