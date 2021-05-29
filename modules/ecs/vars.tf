variable "service_name" {}
variable "app_mesh" {}
variable "task_identifier" {}
variable "container_port" {}
variable "image" {}
variable "environment" {}
variable "aws_region_name" {}
variable "cluster" {}
variable "security_groups" {}
variable "subnets" {}
variable "private_dns_namespace" {}
variable "vpc" {}

variable "tags" {
  type        = map
  default = {}
}

variable "desired_count" {
  type        = number
  default = 1
}

variable "backends" {
  type        = list
  default = []
}

variable "virtual_node_listener_enable" {
  description = "If set to true, enable auto scaling"
  type        = bool
  default = false
}


variable "proxy_configuration_enable" {
  description = "If set to true, enable auto scaling"
  type        = bool
  default = false
}

variable "lb_target_group" {
  description = "If set to true, enable auto scaling"
  type        = any
  default = null
}

variable "private_dns" {}
