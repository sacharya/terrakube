provider "openstack" {
  user_name  = "${var.username}"
  tenant_name = "${var.tenant_name}"
  password  = "${var.password}"
  auth_url  = "${var.auth_url}"
}

# Create a keypair
resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.name_prefix}-keypair"
  public_key = "${file("${var.ssh_pub_key_file}")}"
}
resource "openstack_compute_secgroup_v2" "secgroup" {
  name = "${var.name_prefix}-secgroup"
  description = "Kube security group"
  rule {
    ip_protocol = "icmp"
    from_port = -1
    to_port = -1
    cidr = "0.0.0.0/0"
  }
  rule {
    ip_protocol = "tcp"
    from_port = 1
    to_port = 65535
    cidr = "0.0.0.0/0"
  }
}
resource "template_file" "kubernetes" {
  filename = "files/kubernetes.env"
  vars {
    etcd_cluster_name = "${var.etcd_cluster_name}"
    etcd_discovery_url = "${var.etcd_discovery_url}"    
    service_cluster_ip_range = "${var.service_cluster_ip_range}"
  }
}
resource "template_file" "tokens" {
  filename = "files/tokens.csv"
  vars {
    kubelet_token = "${var.kubelet_token}"
    kube_proxy_token = "${var.kube_proxy_token}"
  }
}
resource "template_file" "kubeconfig" {
  filename = "files/kubeconfig"
  vars {
    kubelet_token = "${var.kubelet_token}"
  }
}
resource "template_file" "kube-proxy-config" {
  filename = "files/kube-proxy-config"
  vars {
    kube_proxy_token = "${var.kube_proxy_token}"
  }
}
# Create kubernetes master node
resource "openstack_compute_instance_v2" "terrakube-kube-master" {
   name = "${var.name_prefix}_master"
   image_id = "${var.image_id}"
   flavor_id = "${var.flavor_id}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   security_groups = ["${openstack_compute_secgroup_v2.secgroup.name}"]
   config_drive="true"
   user_data="${file("files/cloud-config.yaml")}"
   network {
      uuid = "${var.private_net_id}"
   }
  provisioner "file" {
      source = "units/"
      destination = "/tmp/"
      connection {
        user = "core"
        key_file = "${var.ssh_priv_key_file}"
        agent = false
      }
  }
  provisioner "remote-exec" {
     inline = [
        "sudo mkdir -p /opt",
        "sudo wget https://storage.googleapis.com/kubernetes-release/release/v1.0.5/kubernetes.tar.gz -O /opt/kubernetes.tar.gz",
        "sudo rm -rf /opt/kubernetes || false",
        "sudo tar -xzf /opt/kubernetes.tar.gz -C /tmp/",
        "sudo tar -xzf /tmp/kubernetes/server/kubernetes-server-linux-amd64.tar.gz -C /opt/",

        "sudo bash -c \"cat <<'EOF' > /opt/.kubernetes_auth\nadmin:admin\nEOF\"",
        "sudo git clone https://github.com/thommay/kubernetes_nginx /opt/kubernetes_nginx",
        "sudo /opt/kubernetes_nginx/git-kubernetes-nginx.sh",
        "sudo /usr/bin/cp /opt/.kubernetes_auth /opt/kubernetes_nginx/.kubernetes_auth",

        "sudo bash -c \"cat <<'EOF' > /tmp/kubernetes.env\n${template_file.kubernetes.rendered}\nEOF\"",
        "echo 'ETCD_NAME=${self.name}' | sudo tee -a /tmp/kubernetes.env",
        "echo 'ETCD_ADDR=${self.network.0.fixed_ip_v4}:4001'  | sudo tee -a /tmp/kubernetes.env",
        "echo 'ETCD_PEER_ADDR=${self.network.0.fixed_ip_v4}:7001'  | sudo tee -a /tmp/kubernetes.env",
        "echo 'ETCD_PEER_BIND_ADDR=${self.network.0.fixed_ip_v4}:7001'  | sudo tee -a /tmp/kubernetes.env",

        "sudo cp /tmp/kubernetes.env /etc/kubernetes.env",
        "sudo cp /tmp/flannel.service /etc/systemd/system/flannel.service",
        "sudo cp /tmp/docker.service /etc/systemd/system/docker.service",
        "sudo cp /tmp/etcd.service /etc/systemd/system/etcd.service",
        
        "sudo systemctl restart docker",
        "sudo systemctl restart etcd",

        "sudo chown -R core:core /opt/kubernetes",
        "sudo mkdir /opt/bin",
        "sudo /usr/bin/ln -sf /opt/kubernetes/server/bin/kube-apiserver /opt/bin/kube-apiserver",
        "sudo bash -c \"cat <<'EOF' > /tmp/known_tokens.csv\n${template_file.tokens.rendered}\nEOF\"",
        "sudo /usr/bin/mkdir -p /var/lib/kube-apiserver",
        "sudo chown -R core:core /var/lib/kube-apiserver",
        "sudo cp /tmp/known_tokens.csv /var/lib/kube-apiserver/known_tokens.csv",
        "sudo cp /tmp/kube-apiserver.service /etc/systemd/system/kube-apiserver.service",
        "sudo systemctl restart kube-apiserver.service",

        "echo 'MASTER_IP=\"${self.network.0.fixed_ip_v4}\"' | sudo tee -a /etc/kubernetes.env",
        "sudo cp /tmp/apiserver-advertiser.service /etc/systemd/system/apiserver-advertiser.service",
        "sudo systemctl restart apiserver-advertiser.service",

        "sudo cp /tmp/kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service",
        "sudo systemctl restart kube-controller-manager.service",
        "sudo cp /tmp/kube-scheduler.service /etc/systemd/system/kube-scheduler.service",
        "sudo systemctl restart kube-scheduler.service",

        "sudo git clone https://github.com/thommay/kubernetes_nginx /opt/kubernetes_nginx",
        "echo 'admin:admin' | sudo tee /opt/.kubernetes_auth",
        "sudo cp  /opt/.kubernetes_auth /opt/kubernetes_nginx/.kubernetes_auth",
        "sudo /opt/kubernetes_nginx/git-kubernetes-nginx.sh",
        "sudo cp /tmp/kube-nginx.service /etc/systemd/system/kube-nginx.service",
        "sudo systemctl restart kube-nginx.service",
     ]
     connection {
        user = "core"
        key_file = "${var.ssh_priv_key_file}"
        agent = false
     }
   }
   depends_on = [
        "template_file.kubernetes",
    ]
}

# Create kubernetes worker nodes
resource "openstack_compute_instance_v2" "terrakube-kube-workers" {
   count = "${var.worker_count}"
   name = "${var.name_prefix}_worker${count.index}"
   image_id = "${var.image_id}"
   flavor_id = "${var.flavor_id}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   security_groups = ["${openstack_compute_secgroup_v2.secgroup.name}"]
   config_drive="true"
   user_data="${file("files/cloud-config.yaml")}"
   network {
    uuid = "${var.private_net_id}"
   }
   provisioner "file" {
      source = "units/"
      destination = "/tmp/"
      connection {
        user = "core"
        key_file = "${var.ssh_priv_key_file}"
        agent = false
      }
  }
  provisioner "file" {
      source = "files/"
      destination = "/tmp/"
      connection {
        user = "core"
        key_file = "${var.ssh_priv_key_file}"
        agent = false
      }
  }
  provisioner "remote-exec" {
     inline = [
       "sudo mkdir -p /opt",
        "sudo wget https://storage.googleapis.com/kubernetes-release/release/v1.0.5/kubernetes.tar.gz -O /opt/kubernetes.tar.gz",
        "sudo rm -rf /opt/kubernetes || false",
        "sudo tar -xzf /opt/kubernetes.tar.gz -C /tmp/",
        "sudo tar -xzf /tmp/kubernetes/server/kubernetes-server-linux-amd64.tar.gz -C /opt/",
        "sudo chown -R core:core /opt/kubernetes",
        "sudo mkdir /opt/bin",

        "sudo bash -c \"cat <<'EOF' > /tmp/kubernetes.env\n${template_file.kubernetes.rendered}\nEOF\"",
        "echo 'ETCD_NAME=${self.name}' | sudo tee -a /tmp/kubernetes.env",
        "echo 'ETCD_ADDR=${self.network.0.fixed_ip_v4}:4001'  | sudo tee -a /tmp/kubernetes.env",
        "echo 'ETCD_PEER_ADDR=${self.network.0.fixed_ip_v4}:7001'  | sudo tee -a /tmp/kubernetes.env",
        "echo 'ETCD_PEER_BIND_ADDR=${self.network.0.fixed_ip_v4}:7001'  | sudo tee -a /tmp/kubernetes.env",
        "echo 'HOSTNAME_OVERRIDE=--hostname_override=${self.network.0.fixed_ip_v4}' | sudo tee -a /tmp/kubernetes.env",

        "sudo cp /tmp/kubernetes.env /etc/kubernetes.env",
        "sudo cp /tmp/etcd.service /etc/systemd/system/etcd.service",
        "sudo systemctl restart etcd",


        "echo '[NetDev]' | sudo tee /tmp/cbr0.netdev",
        "echo 'Kind=bridge' | sudo tee -a /tmp/cbr0.netdev",
        "echo 'Name=cbr0' | sudo tee -a /tmp/cbr0.netdev",
        "sudo cp /tmp/cbr0.netdev /etc/systemd/network/cbr0.netdev",

        "echo '[Match]' | sudo tee /tmp/cbr0.network",
        "echo 'Name=cbr0' | sudo tee -a /tmp/cbr0.network",
        "echo '[Network]' | sudo tee -a /tmp/cbr0.network",
        "echo 'Address=10.0.${count.index+ 1}.1/24' | sudo tee -a /tmp/cbr0.network",
        "sudo cp /tmp/cbr0.network /etc/systemd/network/cbr0.network",

        "sudo chmod 0755 /tmp/apiservers-list.sh",
        "sudo cp /tmp/apiservers-finder.service /etc/systemd/system/apiservers-finder.service",
        "sudo systemctl restart apiservers-finder.service",

        "sudo /usr/bin/mkdir -p /etc/systemd/system/flanneld.service.d",
        "sudo cp /tmp/flannel.service /etc/systemd/system/flanneld.service.d/50-flannel.conf",

        "sudo /usr/bin/mkdir -p /etc/systemd/system/docker.service.d",
        "sudo cp /tmp/docker.service /etc/systemd/system/docker.service.d/51-docker-mirror.conf",
        "sudo systemctl enable systemd-networkd",
        "sudo systemctl restart systemd-networkd",
        "sudo systemctl restart flanneld.service",
        "sudo systemctl restart docker.service",

        "sudo bash -c \"cat <<'EOF' > /tmp/kubeconfig\n${template_file.kubeconfig.rendered}\nEOF\"",
        "sudo /usr/bin/mkdir -p /var/lib/kubelet",
        "sudo chown -R core:core /var/lib/kubelet",
        "sudo cp /tmp/kubeconfig /var/lib/kubelet/kubeconfig",
        "sudo cp /tmp/kube-kubelet.service /etc/systemd/system/kube-kubelet.service",
        "sudo systemctl restart kube-kubelet.service",

        "sudo bash -c \"cat <<'EOF' > /tmp/kube-proxy-config\n${template_file.kube-proxy-config.rendered}\nEOF\"",
        "sudo /usr/bin/mkdir -p /var/lib/kube-proxy",
        "sudo chown -R core:core /var/lib/kube-proxy",
        "sudo cp /tmp/kube-proxy-config /var/lib/kube-proxy/kube-proxy-config",
        "sudo cp /tmp/kube-proxy.service /etc/systemd/system/kube-proxy.service",
        "sudo systemctl restart kube-proxy.service",
     ]
     connection {
        user = "core"
        key_file = "${var.ssh_priv_key_file}"
        agent = false
     }
   }
   depends_on = [
        "openstack_compute_instance_v2.terrakube-kube-master",
        "template_file.kubernetes",
    ]
}

output "master_ip" {
  value = "${openstack_compute_instance_v2.terrakube-kube-master.network.0.fixed_ip_v4}"
}

output "worker_ips" {
  value = "${join(",", "${formatlist("%s", openstack_compute_instance_v2.terrakube-kube-workers.*.network.0.fixed_ip_v4)}")}"
}
