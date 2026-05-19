variable "prefix" {
  type        = string
  description = "(Required) Prefix used to name Managed Flink resources."

  validation {
    condition     = length(var.prefix) > 0
    error_message = "Prefix cannot be empty."
  }
}

variable "environment" {
  type        = string
  description = "(Required) Deployment environment name."

  validation {
    condition     = length(var.environment) > 0
    error_message = "Environment cannot be empty."
  }
}

variable "aws_region" {
  type        = string
  description = "(Required) AWS region from the shared Terragrunt root inputs."

  validation {
    condition     = length(var.aws_region) > 0
    error_message = "AWS region cannot be empty."
  }
}

variable "application_zip_path" {
  type        = string
  description = "(Required) Local path to the packaged Managed Flink application zip."

  validation {
    condition     = length(var.application_zip_path) > 0
    error_message = "Application zip path cannot be empty."
  }
}

variable "kafka_bootstrap_servers" {
  type        = string
  description = "(Required) Kafka bootstrap endpoint."

  validation {
    condition     = length(var.kafka_bootstrap_servers) > 0
    error_message = "Kafka bootstrap servers cannot be empty."
  }
}

variable "kafka_topic" {
  type        = string
  description = "(Required) Kafka topic consumed by the Managed Flink app."

  validation {
    condition     = length(var.kafka_topic) > 0
    error_message = "Kafka topic cannot be empty."
  }
}

variable "kafka_api_key" {
  type        = string
  description = "(Required) Kafka API key consumed by the Managed Flink app."
  sensitive   = true

  validation {
    condition     = length(var.kafka_api_key) > 0
    error_message = "Kafka API key cannot be empty."
  }
}

variable "kafka_api_secret" {
  type        = string
  description = "(Required) Kafka API secret consumed by the Managed Flink app."
  sensitive   = true

  validation {
    condition     = length(var.kafka_api_secret) > 0
    error_message = "Kafka API secret cannot be empty."
  }
}

variable "kafka_group_id" {
  type        = string
  description = "(Required) Kafka consumer group ID consumed by the Managed Flink app."

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.kafka_group_id))
    error_message = "Kafka group ID may contain only letters, numbers, dots, underscores, and hyphens."
  }
}

variable "s3_bronze_uri" {
  type        = string
  description = "(Required) S3 URI where bronze Parquet files are written."

  validation {
    condition     = can(regex("^s3://[^/]+/.+", var.s3_bronze_uri))
    error_message = "Bronze URI must be an S3 URI with a bucket and prefix."
  }
}

variable "start_application" {
  type        = bool
  description = "(Optional) Start the Managed Flink application after deployment. Keep false by default to avoid ongoing KPU charges."
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "(Optional) CloudWatch log retention in days."
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Log retention days must be a CloudWatch-supported retention value."
  }
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Tags applied to Managed Flink resources."
  default     = {}
}
