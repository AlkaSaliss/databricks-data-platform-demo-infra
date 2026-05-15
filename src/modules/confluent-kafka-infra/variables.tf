variable "environment" {
  type        = string
  description = "(Required) Deployment environment name."

  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment cannot be empty."
  }
}

variable "region" {
  type        = string
  description = "(Required) Confluent Cloud region for the Kafka cluster."

  validation {
    condition     = length(var.region) > 0
    error_message = "Region cannot be empty."
  }
}

variable "prefix" {
  type        = string
  description = "(Required) Prefix used to name Confluent resources."

  validation {
    condition     = length(var.prefix) > 0
    error_message = "Prefix cannot be empty."
  }
}

variable "confluent_cloud_api_key" {
  type        = string
  description = "(Required) Confluent Cloud API key used by Terraform."
  sensitive   = true

  validation {
    condition     = length(var.confluent_cloud_api_key) > 0
    error_message = "Confluent Cloud API key cannot be empty. Set CONFLUENT_CLOUD_API_KEY before running Terragrunt."
  }
}

variable "confluent_cloud_api_secret" {
  type        = string
  description = "(Required) Confluent Cloud API secret used by Terraform."
  sensitive   = true

  validation {
    condition     = length(var.confluent_cloud_api_secret) > 0
    error_message = "Confluent Cloud API secret cannot be empty. Set CONFLUENT_CLOUD_API_SECRET before running Terragrunt."
  }
}

variable "topic_name" {
  type        = string
  description = "(Required) Kafka topic name to create for the first local producer."

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.topic_name)) && length(var.topic_name) <= 249
    error_message = "Topic name must be 249 characters or fewer and contain only letters, numbers, dots, underscores, and hyphens."
  }
}

variable "topic_partitions_count" {
  type        = number
  description = "(Optional) Number of Kafka partitions for the producer MVP topic."
  default     = 1

  validation {
    condition     = var.topic_partitions_count > 0
    error_message = "Topic partitions count must be greater than zero."
  }
}

variable "topic_retention_ms" {
  type        = string
  description = "(Optional) Kafka topic retention in milliseconds."
  default     = "604800000"
}

variable "flink_consumer_group_id" {
  type        = string
  description = "(Optional) Kafka consumer group ID used by the local Flink bronze sink."
  default     = "energy-market-flink-bronze"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.flink_consumer_group_id))
    error_message = "Flink consumer group ID may contain only letters, numbers, dots, underscores, and hyphens."
  }
}
