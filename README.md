# TerraKube

TerraKube is a simple tool to provision a Kubernetes cluster on top of OpenStack using Terraform. If you are unfamiliar with Terraform, here's how it compares to OpenStack Heat.
[Terraform or Heat] (https://terraform.io/intro/vs/cloudformation.html)

## Status
Work in progress. Can be used to for testing a very basic Kubernetes cluster.

## Architecture
* **TerraKube Node**: Terraform, Terrakube
* **Kubernetes Master**: CoreOS, etcd, kube-api, kube-scheduler, kube-controller-manager
* **Kubernetes Nodes**: CoreOS, etcd, kube-kubelet, kube-proxy, flannel, docker

## Installation
#### 1. Install Terraform
Follow the instructions from here: https://www.terraform.io/intro/getting-started/install.html

#### 2. Upload CoreOS Image to OpenStack Glance
```
wget http://stable.release.core-os.net/amd64-usr/current/coreos_production_openstack_image.img.bz2
bunzip2 coreos_production_openstack_image.img.bz2
glance image-create --name CoreOs --container-format bare --disk-format qcow2 --file coreos_production_openstack_image.img --is-public True
```

## 3. Configure Terrakube
```
cd terrakube
mv terraform.tfvars.example terraform.tfvars
```
Edit your terraform.tfvars with your configuration info. Most of the configuration should be pretty straight forward.

Please note that you have to get a new etcd_discovery_url for every new cluster. Take a look at restart.sh for example, where the etcd_discovery_url in the terraform.vars file is updated with a new value before you apply the terraform plan/

#### 4. Using Terrakube
Show the execution plan
```
terraform plan
```
Execute the plan
```
terraform apply
```

You should get an output like:
```
Outputs:

  master_ip  = 10.0.0.50
  worker_ips = 10.0.0.51
```

Login to the master and make sure all make sure services are up.
```
ssh core@10.0.0.50
cd /opt/kubernetes/server/bin
./kubectl get cluster-info
./kubectl get nodes
```

#### 5. Running some examples
Kubernetes comes with a lot of examples that you can try out. Note that many of the examples are configured to run on top of Google Container Engine (GKE), and may not run on top of OpenStack without some tweaking. But the manifests are a pretty good starting point to learn about deployong apps pn Kubernetes.
```
git clone https://github.com/kubernetes/kubernetes ~/kubernetes
```
Try out the guestbook example under examples/guestbook

### Credits: 
TerraKube was mostly inspired by:
* @doublerr: https://github.com/kubernetes/kubernetes/tree/master/cluster/rackspace


