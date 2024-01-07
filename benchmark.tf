data "openstack_images_image_v2" "debian_12" {
  name        = "debian-12-x86_64"
  most_recent = true
  visibility  = "public"
}
data "openstack_dns_zone_v2" "dns_zone" {
   name = var.dns_zone
}

resource "openstack_compute_servergroup_v2" "benchmark-instance-group" {
  name     = "benchmark-instance-group"
  policies = ["anti-affinity"]
}

locals {
  timescale_docker_compose = filebase64("${path.module}/timescale.docker-compose.yaml")
  influxdb_v1_docker_compose = filebase64("${path.module}/influxdb_v1.docker-compose.yaml")
  influxdb_v2_docker_compose = filebase64("${path.module}/influxdb_v2.docker-compose.yaml")
}

resource "openstack_compute_instance_v2" "ts_db" {
  name            = "ts_db"
  user_data       = templatefile("cloud-init_db.tpl", { ts_db_kind = var.ts_db_kind,
  timescale_docker_compose = local.timescale_docker_compose,
  influxdb_v1_docker_compose = local.influxdb_v1_docker_compose,
  influxdb_v2_docker_compose = local.influxdb_v2_docker_compose,
  ssh_key = var.ssh_key,
  netdata_token = var.netdata_token,
  netdata_room = var.netdata_room,
   })
  flavor_name     = "c5.2xlarge"
  security_groups = [openstack_networking_secgroup_v2.secgroup.name]

  network {
    name = var.network
  }
  block_device {
    uuid                  = data.openstack_images_image_v2.debian_12.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 200
    delete_on_termination = true

  }
  scheduler_hints {
    group = openstack_compute_servergroup_v2.benchmark-instance-group.id
  }

}

resource "openstack_compute_instance_v2" "ts_loadgen" {
  name            = "ts_loadgen"
  user_data       = templatefile("cloud-init_loadgen.tpl",
  { ssh_key = var.ssh_key,
    netdata_token = var.netdata_token,
    netdata_room = var.netdata_room,
  })
  flavor_name     = "c5.2xlarge"
  security_groups = [openstack_networking_secgroup_v2.secgroup.name]

  network {
    name = var.network
  }
  block_device {
    uuid                  = data.openstack_images_image_v2.debian_12.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = 50
    delete_on_termination = true

  }
  scheduler_hints {
    group = openstack_compute_servergroup_v2.benchmark-instance-group.id
  }

}

// security group
resource "openstack_networking_secgroup_v2" "secgroup" {
  name        = "benchmark"
  description = "benchmark security group"
}

// allow ssh
resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_all" {
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 9999
  remote_ip_prefix  = "0.0.0.0/0"
}

# # Allow all Egress IPv4 traffic
# resource "openstack_networking_secgroup_rule_v2" "ingress-secgroup-rule-egress" {
#   direction         = "egress"
#   ethertype         = "IPv4"
#   security_group_id = openstack_networking_secgroup_v2.secgroup.id
# }

# # Allow all Egress IPv6 traffic
# resource "openstack_networking_secgroup_rule_v2" "ingress-secgroup-rule-egress-ipv6" {
#   direction         = "egress"
#   ethertype         = "IPv6"
#   security_group_id = openstack_networking_secgroup_v2.secgroup.id
# }

resource "local_file" "instance_ip" {
  content  = join("\n", [openstack_compute_instance_v2.ts_db.access_ip_v4, openstack_compute_instance_v2.ts_loadgen.access_ip_v4])
  filename = "instance_ip.txt"
}

# DNS 
resource "openstack_dns_recordset_v2" "dns_recordset" {
  name    = "ts-db.${var.dns_zone}."
  zone_id = data.openstack_dns_zone_v2.dns_zone.id
  records = [openstack_compute_instance_v2.ts_db.access_ip_v4]
  type    = "A"
  ttl     = 10
}

resource "openstack_dns_recordset_v2" "dns_recordset_loadgen" {
  name    = "ts-loadgen.${var.dns_zone}."
  zone_id = data.openstack_dns_zone_v2.dns_zone.id
  records = [openstack_compute_instance_v2.ts_loadgen.access_ip_v4]
  type    = "A"
  ttl     = 10
}