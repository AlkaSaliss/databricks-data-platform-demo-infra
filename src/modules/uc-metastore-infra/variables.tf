variable "tags" {
  type        = map(string)
  description = "(Optional) Tags applied to metastore resources"
  default     = {}
}

variable "prefix" {
  type        = string
  description = "(Required) Prefix used to name metastore resources"
}

variable "region" {
  type        = string
  description = "(Required) AWS region for the Unity Catalog metastore"
}

variable "unity_metastore_owner" {
  type        = string
  description = "(Required) Principal that owns the Unity Catalog metastore"
}

variable "metastore_name" {
  type        = string
  description = "(Optional) Name of the metastore to create"
  default     = null
}

variable "databricks_account_id" {
  type        = string
  description = "(Required) Databricks account ID used by the generated provider configuration"

  validation {
    condition     = can(regex("^[a-f0-9-]{36}$", var.databricks_account_id))
    error_message = "Databricks account ID must be a valid UUID."
  }
}

variable "databricks_client_id" {
  type        = string
  description = "(Required) Databricks client ID used by the generated provider configuration"
  sensitive   = true

  validation {
    condition     = length(var.databricks_client_id) > 0
    error_message = "Databricks client ID cannot be empty. Set DATABRICKS_CLIENT_ID before running Terragrunt."
  }
}

variable "databricks_client_secret" {
  type        = string
  description = "(Required) Databricks client secret used by the generated provider configuration"
  sensitive   = true

  validation {
    condition     = length(var.databricks_client_secret) > 0
    error_message = "Databricks client secret cannot be empty. Set DATABRICKS_CLIENT_SECRET before running Terragrunt."
  }
}
