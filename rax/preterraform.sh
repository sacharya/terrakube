#!/bin/sh

DISCOVERY_URL=$(curl https://discovery.etcd.io/new)
DISCOVERY_ID=$(echo "${DISCOVERY_URL}" | cut -f 4 -d /)

KUBE_USER="admin"
KUBE_PASSWORD="admin"

SERVICE_CLUSTER_IP_RANGE="10.0.0.0/16"
: ${OS_AUTH_URL:?"Need to set OS_AUTH_URL non-empty"}
: ${OS_USERNAME:?"Need to set OS_USERNAME non-empty"}
: ${OS_PASSWORD:?"Need to set OS_PASSWORD non-empty"}
: ${OS_TENANT_NAME:?"Need to set OS_TENANT_NAME non-empty"}
: ${OS_REGION_NAME:?"Need to set OS_REGION_NAME non-empty"}

sed -e "s|DISCOVERY_ID|${DISCOVERY_ID}|" \
  -e "s|KUBE_USER|${KUBE_USER}|" \
  -e "s|KUBE_PASSWORD|${KUBE_PASSWORD}|" \
  -e "s|SERVICE_CLUSTER_IP_RANGE|${SERVICE_CLUSTER_IP_RANGE}|" \
  -e "s|OS_AUTH_URL|${OS_AUTH_URL}|" \
  -e "s|OS_USERNAME|${OS_USERNAME}|" \
  -e "s|OS_PASSWORD|${OS_PASSWORD}|" \
  -e "s|OS_TENANT_NAME|${OS_TENANT_NAME}|" \
  -e "s|OS_REGION_NAME|${OS_REGION_NAME}|" \
  kube-master-userdata-template.yaml > kube-master-userdata.yaml

DNS_SERVER_IP="10.0.0.10"
DNS_DOMAIN="cluster.local"
KUBELET_TOKEN=` echo $(cat /dev/urandom | base64 | tr -d "=+/" | dd bs=32 count=1 2> /dev/null)`
KUBE_PROXY_TOKEN=`echo $(cat /dev/urandom | base64 | tr -d "=+/" | dd bs=32 count=1 2> /dev/null)`
echo "${KUBELET_TOKEN},kubelet,kubelet" > tokens.csv
echo "${KUBE_PROXY_TOKEN},kube_proxy,kube_proxy" >> tokens.csv
KUBELET_TOKEN=$(awk -F, '/kubelet/ {print $1}' tokens.csv)
KUBE_PROXY_TOKEN=$(awk -F, '/kube_proxy/ {print $1}' tokens.csv)

KUBE_NETWORK="10.240.0.0/16"
for i in `seq 1 3`;
  do
    sed -e "s|DISCOVERY_ID|${DISCOVERY_ID}|" \
      -e "s|DNS_SERVER_IP|${DNS_SERVER_IP:-}|" \
      -e "s|DNS_DOMAIN|${DNS_DOMAIN:-}|" \
      -e "s|INDEX|$((i + 1))|g" \
      -e "s|KUBELET_TOKEN|${KUBELET_TOKEN}|" \
      -e "s|KUBE_NETWORK|${KUBE_NETWORK}|" \
      -e "s|KUBE_PROXY_TOKEN|${KUBE_PROXY_TOKEN}|" \
      kube-worker-userdata-template.yaml > kube-worker-userdata-$(($i + 1)).yaml
  done
