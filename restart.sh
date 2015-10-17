#!/bin/bash

terraform destroy

DISCOVERY=`curl https://discovery.etcd.io/new`
echo $DISCOVERY
sed -i "s#etcd_discovery_url = .*#etcd_discovery_url = \"$DISCOVERY\"#" terraform.tfvars

terraform apply
