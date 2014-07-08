#!/bin/sh  
# IBM(c) 2013 EPL license http://www.eclipse.org/legal/epl-v10.html


#-------------------------------------------------------------------------------
#=head1  configure_chef_server
#=head2  This command configures the chef server on a xCAT node.
#        It is used by install_chef_client on Ubuntu and chef kit on RH.
#        It also can be used postscripts on diskless
#    usage:  
#      1. configure the chef server using updatenode
#            updatenode <noderange> -P "config_chef_server"
#      2. configure chef server during os provisioning
#            chef <noderange> -p postscripts=config_chef_server
#=cut
#-------------------------------------------------------------------------------
HOME='/root/'
export ${HOME}

knife configure --initial

/usr/bin/chef-server-ctl reconfigure
if [ $? -ne 0 ]
then
    errmsg="Failed to run chef-server-ctl reconfigure on $node"
    logger -t xcat -p local4.err $errmsg
    echo $errmsg
    exit 1
fi

exit 0;
