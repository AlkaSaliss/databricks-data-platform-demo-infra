variable "prefix" {
  description = "Prefix used for AWS and Databricks object names."
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID used as the Unity Catalog external ID fallback."
  type        = string
}

variable "databricks_host" {
  description = "Workspace-level Databricks host URL, including https://."
  type        = string
}

variable "databricks_client_id" {
  description = "Databricks service principal client ID."
  type        = string
  sensitive   = true
}

variable "databricks_client_secret" {
  description = "Databricks service principal client secret."
  type        = string
  sensitive   = true
}

variable "streaming_lake_bucket_name" {
  description = "Existing S3 bucket name populated by local Flink bronze writes."
  type        = string
}

variable "streaming_lake_bucket_arn" {
  description = "Existing S3 bucket ARN populated by local Flink bronze writes."
  type        = string
}

variable "catalog_name" {
  description = "Unity Catalog catalog for the energy market demo."
  type        = string
  default     = "energy_market_demo"
}

variable "bronze_schema_name" {
  description = "Bronze schema name."
  type        = string
  default     = "bronze"
}

variable "silver_schema_name" {
  description = "Silver schema name."
  type        = string
  default     = "silver"
}

variable "gold_schema_name" {
  description = "Gold schema name."
  type        = string
  default     = "gold"
}

variable "volume_name" {
  description = "External volume name exposing the streaming lake bucket."
  type        = string
  default     = "streaming_lake"
}

variable "tags" {
  description = "Tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
