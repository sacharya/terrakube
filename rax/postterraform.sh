#!/bin/sh

MASTER_IP=`nova show suda-kube_master | grep accessIPv4 | awk '{print $4}'`
cat tokens.csv > known_tokens.csv
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa known_tokens.csv core@${MASTER_IP}:/home/core/known_tokens.csv
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa core@${MASTER_IP} sudo /usr/bin/mkdir -p /var/lib/kube-apiserver
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa core@${MASTER_IP} sudo mv /home/core/known_tokens.csv /var/lib/kube-apiserver/known_tokens.csv
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa core@${MASTER_IP} sudo chown root.root /var/lib/kube-apiserver/known_tokens.csv
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa core@${MASTER_IP} sudo systemctl restart kube-apiserver

