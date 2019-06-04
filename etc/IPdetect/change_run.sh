#!/bin/sh

# Place your domain update commands here

# Ie. http://freedns.afraid.org/ gives you update URLs for dynamic
# domains, so you can put them into command:
# curl --silent <update_URL>
# This is tested and works very good.
# This script is run by IPdetect with 2 parameters: the first is the new
# IP address, the second is CHECK_DOMAIN value from IPdetect.conf

# Debugging line...
# echo `/bin/date` "1=$1 2=$2" >>/var/log/IPdetect/change_run.log

exit 0;
