provider "openstack" {
    user_name  = "${var.user_name}"
    tenant_name = "${var.tenant_name}"
    password  = "${var.password}"
    auth_url  = "${var.auth_url}"
}

# Create a keypair
resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.name_prefix}-keypair"
  public_key = "${file("/root/.ssh/id_rsa.pub")}"
  region = "${var.region}"
}

# Create a Neutron private Network
#resource "openstack_networking_network_v2" "private_net" {
#  name="${var.name_prefix}_net"
#  admin_state_up = "true"
#  tenant_id = "${var.tenant_name}"
#  region = "${var.region}"
#}

# Create a Neutron Subnet for the network
#resource "openstack_networking_subnet_v2" "private_subnet" {
#  name="${var.name_prefix}_subnet"
#  tenant_id = "${var.tenant_name}"
#  network_id = "${openstack_networking_network_v2.private_net.id}"
#  enable_dhcp = "true"
#  cidr = "192.168.5.0/24"
#  ip_version = 4
#  dns_nameservers = ["8.8.4.4","8.8.8.8"]
#  region = "${var.region}"
#}

# Create kubernetes master node
resource "openstack_compute_instance_v2" "suda-terraform-kube-master" {
   name = "${var.name_prefix}_master"
   image_id = "${var.image_id}"
   flavor_id = "${var.flavor_id}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   config_drive="true"
   user_data="${file("kube-master-userdata.yaml")}"
   network {
      uuid = "11111111-1111-1111-1111-111111111111"
   }
   network {
      uuid = "00000000-0000-0000-0000-000000000000"
   }
   network {
       uuid ="${var.private_net_id}"
   }
   region = "${var.region}"   
}

# Create kubernetes worker nodes
resource "openstack_compute_instance_v2" "suda-terraform-kube-workers" {
   count = "${var.worker_count}"
   name = "${var.name_prefix}_worker${count.index}"
   image_id = "${var.image_id}"
   flavor_id = "${var.flavor_id}"
   key_pair = "${openstack_compute_keypair_v2.keypair.name}"
   config_drive="true"
   user_data="${file("kube-worker-userdata.yaml")}"
   network {
     uuid = "11111111-1111-1111-1111-111111111111"
   }
   network {
     uuid = "00000000-0000-0000-0000-000000000000"
   } 
   network {
    uuid = "${var.private_net_id}"
   }
   region = "${var.region}"
}
