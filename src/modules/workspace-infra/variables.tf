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

  validation {
    condition     = can(regex("^[a-f0-9-]{36}$", var.databricks_account_id))
    error_message = "Databricks account ID must be a valid UUID."
  }
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

  validation {
    condition     = length(var.databricks_client_id) > 0
    error_message = "Databricks client ID cannot be empty. Set DATABRICKS_CLIENT_ID before running Terragrunt."
  }
}

variable "databricks_client_secret" {
  type        = string
  description = "(Required) Client secret to authenticate the Databricks provider at the account level"
  sensitive   = true

  validation {
    condition     = length(var.databricks_client_secret) > 0
    error_message = "Databricks client secret cannot be empty. Set DATABRICKS_CLIENT_SECRET before running Terragrunt."
  }
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

variable "lakehouse_prefix" {
  type        = string
  description = "(Optional) Prefix used for demo lakehouse AWS and Databricks object names."
  default     = null
}

variable "streaming_lake_bucket_name" {
  type        = string
  description = "(Required) S3 bucket name populated by local Flink bronze writes."
}

variable "streaming_lake_bucket_arn" {
  type        = string
  description = "(Required) S3 bucket ARN populated by local Flink bronze writes."
}

variable "lakehouse_catalog_name" {
  type        = string
  description = "(Optional) Unity Catalog catalog for the energy market demo."
  default     = "energy_market_demo"
}

variable "lakehouse_bronze_schema_name" {
  type        = string
  description = "(Optional) Bronze schema name for the energy market demo."
  default     = "bronze"
}

variable "lakehouse_silver_schema_name" {
  type        = string
  description = "(Optional) Silver schema name for the energy market demo."
  default     = "silver"
}

variable "lakehouse_gold_schema_name" {
  type        = string
  description = "(Optional) Gold schema name for the energy market demo."
  default     = "gold"
}

variable "streaming_lake_volume_name" {
  type        = string
  description = "(Optional) External volume name exposing the streaming lake bucket."
  default     = "streaming_lake"
}
