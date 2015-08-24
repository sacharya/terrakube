provider "openstack" {
  user_name  = "${var.username}"
  tenant_name = "${var.tenant_name}"
  password  = "${var.password}"
  auth_url  = "${var.auth_url}"
}

# Create a keypair
resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.name_prefix}-keypair"
  public_key = "${file("/home/stack/.ssh/id_rsa.pub")}"
}

resource "template_file" "cloudconf" {
  filename = "cloud.conf"
  vars {
    auth_url = "${var.auth_url}"
    username = "${var.username}"
    password = "${var.password}"
    tenant_name = "${var.tenant_name}"
    subnet_id = "${var.subnet_id}"
  }
}
# Create kubernetes master node
resource "openstack_compute_instance_v2" "suda-terraform-kube-master" {
   name = "${var.name_prefix}_master"
   image_id = "${var.image_id}"
   flavor_id = "${var.flavor_id}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   config_drive="true"
   user_data="${file("cloud-config.yaml")}"
   network {
      uuid = "${var.private_net_id}"
   }
   provisioner "file" {
      source = "tokens.csv"
      destination = "/tmp/known_tokens.csv"
      connection {
        user = "core"
        key_file = "/home/stack/.ssh/id_rsa"
        agent = false
      } 
  }
   provisioner "remote-exec" {
     inline = [
        "sudo bash -c \"echo 'nameserver 8.8.8.8' >> /etc/resolv.conf\"",

        "sudo bash -c \"cat <<'EOF' > /etc/cloud.conf\n${template_file.cloudconf.rendered}\nEOF\"",

        "sudo mkdir -p /opt",
        "sudo wget https://storage.googleapis.com/kubernetes-release/release/v0.21.3/kubernetes.tar.gz -O /opt/kubernetes.tar.gz",
        "sudo rm -rf /opt/kubernetes || false",
        "sudo tar -xzf /opt/kubernetes.tar.gz -C /tmp/",
        "sudo tar -xzf /tmp/kubernetes/server/kubernetes-server-linux-amd64.tar.gz -C /opt/",

        "sudo bash -c \"cat <<'EOF' > /opt/.kubernetes_auth\nadmin:admin\nEOF\"",
        "sudo git clone https://github.com/thommay/kubernetes_nginx /opt/kubernetes_nginx",
        "sudo /opt/kubernetes_nginx/git-kubernetes-nginx.sh",
        "sudo /usr/bin/cp /opt/.kubernetes_auth /opt/kubernetes_nginx/.kubernetes_auth",

        "sudo mkdir -p /etc/etcd",
        "sudo bash -c \"echo 'name:${var.etcd_name}' > /etc/etcd/etcd.conf\"",
        "sudo bash -c \"echo 'discovery:${var.etcd_discovery}' >> /etc/etcd/etcd.conf\"",
        "sudo bash -c \"echo 'addr:http://${openstack_compute_instance_v2.suda-terraform-kube-master.network.0.fixed_ip_v4}:4001' >> /etc/etcd/etcd.conf\"",
        "sudo bash -c \"echo 'peer-addr:http://${openstack_compute_instance_v2.suda-terraform-kube-master.network.0.fixed_ip_v4}:7001' >> /etc/etcd/etcd.conf\"",
        "sudo bash -c \"echo 'peer-bind-addr:http://${openstack_compute_instance_v2.suda-terraform-kube-master.network.0.fixed_ip_v4}:7001' >> /etc/etcd/etcd.conf\"",
        "sudo systemctl restart etcd",

        "sudo mkdir -p /etc/fleet",
        "sudo bash -c \"echo 'public-ip: ${openstack_compute_instance_v2.suda-terraform-kube-master.network.0.fixed_ip_v4}' > /etc/fleet/fleet.conf\"",
        "sudo bash -c \"echo 'metadata: kubernetes_role=master' >> /etc/fleet/fleet.conf\"",
        "sudo systemctl restart fleet",

        "sudo chown -R core:core /opt/kubernetes",
        "sudo mkdir /opt/bin",
        "sudo /usr/bin/ln -sf /opt/kubernetes/server/bin/kube-apiserver /opt/bin/kube-apiserver",
        "sudo /usr/bin/mkdir -p /var/lib/kube-apiserver",
        "sudo chown -R core:core /var/lib/kube-apiserver",
        "sudo cp /tmp/known_tokens.csv /var/lib/kube-apiserver/known_tokens.csv",
     ]
     connection {
        user = "core"
        key_file = "/home/stack/.ssh/id_rsa"
        agent = false
     }
   }
}

# Create kubernetes worker nodes
resource "openstack_compute_instance_v2" "suda-terraform-kube-workers" {
   count = "${var.worker_count}"
   name = "${var.name_prefix}_worker${count.index}"
   image_id = "${var.image_id}"
   flavor_id = "${var.flavor_id}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   network {
    uuid = "${var.private_net_id}"
   }
}

output "master_ip" {
  value = "${openstack_compute_instance_v2.suda-terraform-kube-master.addresses.private.addr}"
}

output "worker_ips" {
  value = "${join(",", "${formatlist("%s", openstack_compute_instance_v2.suda-terraform-kube-workers.*.access_ip_v4)}")}"
}
