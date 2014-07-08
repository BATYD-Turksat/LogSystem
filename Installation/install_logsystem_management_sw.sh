#!/bin/bash
#install_logsystem_management_sw.sh
# Created on: May 29, 2014
#     Author: eozekes

#install kopf for ealsticsearch
cd /usr/local/elasticsearch/
./bin/plugin -install lmenezes/elasticsearch-kopf

#install rabbitmq management sw
rabbitmq-plugins enable rabbitmq_management
service rabbitmq-server restart
