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
}

variable "databricks_client_id" {
  type        = string
  description = "(Required) Databricks client ID used by the generated provider configuration"
  sensitive   = true
}

variable "databricks_client_secret" {
  type        = string
  description = "(Required) Databricks client secret used by the generated provider configuration"
  sensitive   = true
}
