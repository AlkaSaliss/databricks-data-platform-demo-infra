variable "tags" {
  type        = map(string)
  description = "(Required) Tags applied to the network resources"
}

variable "prefix" {
  type        = string
  description = "(Required) Prefix for the resources deployed by this module"
}

variable "cidr_block" {
  type        = string
  description = "(Required) CIDR block for the VPC that will be used to create the Databricks workspace"
}
