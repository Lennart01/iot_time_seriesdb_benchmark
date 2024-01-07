terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
  }
}
provider "openstack" {
  cloud = var.openstack_cloud_name
}