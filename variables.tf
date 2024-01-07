variable "ts_db_kind" {
  type        = string
  description = "One of the following: 'timescaledb', 'influxdb_v1', 'questdb', 'influxdb_v2'"
}

variable "openstack_cloud_name" {
  type        = string
  description = "Name of the openstack cloud, used in main.tf"
}
variable "ssh_key" {
    type        = string
    description = "SSH Public Key used for the instances"
}
variable "netdata_token" {
    type        = string
    description = "Netdata token used to add the instances to netdata cloud"
}
variable "netdata_room" {
    type        = string
    description = "Netdata room used to add the instances to netdata cloud"
}
variable "dns_zone" {
    type        = string
    description = "DNS Zone used for the instances"
}
variable "network" {
    type        = string
    description = "Network used for the instances"
}