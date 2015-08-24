#!/bin/bash
KUBELET_TOKEN=` echo $(cat /dev/urandom | base64 | tr -d "=+/" | dd bs=32 count=1 2> /dev/null)`
KUBE_PROXY_TOKEN=`echo $(cat /dev/urandom | base64 | tr -d "=+/" | dd bs=32 count=1 2> /dev/null)`
echo "${KUBELET_TOKEN},kubelet,kubelet" > tokens.csv
echo "${KUBE_PROXY_TOKEN},kube_proxy,kube_proxy" >> tokens.csv


