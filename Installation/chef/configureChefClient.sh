#!/bin/sh
# IBM(c) 2013 EPL license http://www.eclipse.org/legal/epl-v10.html


#-------------------------------------------------------------------------------
#=head1  config_chef_client
#=head2  This command configures the chef client on a xCAT node.
#        It is used by install_chef_client on Ubuntu and chef kit on RH. 
#=cut
#-------------------------------------------------------------------------------

echo "Configuring chef client....."
#the chef server can be passed as an argument or as an environmental variable
#the default is $SITEMASTER
ARGNUM=$#;
if [ $ARGNUM -gt 1 ]; then
    if [ $1 = "-s" ]; then
        chef_server=$2
    fi
fi

if [ -z "$chef_server" ]; then
    if [ -n "$CFGSERVER" -a -n "$CFGMGR" ]; then
        if [ $CFGMGR = "chef" ]; then
            chef_server=$CFGSERVER
        fi
    fi
    if [ -z "$chef_server" ]
    then
        chef_server=$CHEFSERVER
    fi
    if [ -z "$chef_server" ]; then
        chef_server=$SITEMASTER
    fi
fi

chef_server=${chef_server}

mkdir -p /etc/chef

# copy the validator.pem to chef client
scp root@$chef_server:/etc/chef-server/chef-validator.pem /etc/chef/validation.pem


# Add the info to /etc/chef/client.rb
echo -e "log_level        :auto
log_location     STDOUT
chef_server_url  'https://$chef_server'
validation_client_name 'chef-validator'" > /etc/chef/client.rb

node=`hostname`

# run the command on the client to register the client on the chef-server
/opt/chef/bin/chef-client

if [ $? -ne 0 ]
then
    errmsg="Failed to run /opt/chef/bin/chef-client on $node"
    logger -t xcat -p local4.err $errmsg
    echo $errmsg
    exit 1
fi

exit 0;
