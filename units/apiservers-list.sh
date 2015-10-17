#!/bin/sh
m=$(echo $(etcdctl ls --recursive /corekube/apiservers | cut -d/ -f4 | sort) | tr ' ' ,)
echo "API_SERVERS=$m" > /etc/apiservers.env
