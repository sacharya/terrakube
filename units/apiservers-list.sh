#!/bin/sh
m=$(echo $(etcdctl ls --recursive /corekube/apiservers | cut -d/ -f4 | sort) | tr ' ' ,)
echo "API_SERVERS=--api_servers=https://${m%%\,*}:6443" > /etc/apiservers.env
echo "MASTER=--master=https://${m%%\,*}:6443" >> /etc/apiservers.env
