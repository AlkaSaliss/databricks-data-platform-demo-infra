# Variables for the Databricks workspace infrastructure module

variable "tags" {
  default     = {}
  type        = map(string)
  description = "(Optional) List of tags to be propagated across all assets in this module"
}

variable "prefix" {
  type        = string
  description = "(Required) Prefix to name the resources created by this module"
}

variable "region" {
  type        = string
  description = "(Required) AWS region where the assets will be deployed"
}

variable "vpc_id" {
  type        = string
  description = "(Required) VPC ID for the Databricks workspace network"
}

variable "subnet_ids" {
  type        = list(string)
  description = "(Required) Private subnet IDs for the Databricks workspace network"
}

variable "security_group_ids" {
  type        = list(string)
  description = "(Required) Security group IDs for the Databricks workspace network"
}

variable "databricks_account_id" {
  type        = string
  description = "(Required) Databricks Account ID"
}

variable "workspace_name" {
  type        = string
  default     = ""
  description = "(Optional) Workspace Name for this module - if none are provided, the prefix will be used to name the workspace"
}

variable "metastore_id" {
  type        = string
  description = "(Required) Unity Catalog metastore ID to assign to the workspace"
}

variable "databricks_client_id" {
  type        = string
  description = "(Required) Client ID to authenticate the Databricks provider at the account level"
  sensitive   = true
}

variable "databricks_client_secret" {
  type        = string
  description = "(Required) Client secret to authenticate the Databricks provider at the account level"
  sensitive   = true
}

variable "admin_group_id" {
  type        = string
  description = "(Required) The ID of the Databricks group to be granted admin permissions on the workspace."
}

variable "ws_users" {
  type        = list(string)
  description = "(Optional) List of users to be granted regular access to the workspace."
  default     = []
}

variable "roles_to_assume" {
  type        = list(string)
  description = "(Optional) AWS role ARNs that the Databricks cross-account role can pass"
  default     = []
}
