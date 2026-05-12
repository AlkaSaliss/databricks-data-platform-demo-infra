# Variables for Terraform State Management Module

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be lowercase, contain only letters, numbers, and hyphens, and start/end with alphanumeric characters."
  }
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.dynamodb_table_name))
    error_message = "DynamoDB table name must contain only letters, numbers, underscores, periods, and hyphens."
  }
}

variable "enable_versioning" {
  description = "Enable versioning on the S3 bucket"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption on the S3 bucket"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules for the S3 bucket"
  type = list(object({
    id     = string
    status = string
    noncurrent_version_expiration = optional(object({
      days = number
    }))
    abort_incomplete_multipart_upload = optional(object({
      days_after_initiation = number
    }))
  }))
  default = []
}

variable "tags" {
  description = "Additional tags to apply to resources on top of provider default tags"
  type        = map(string)
  default     = {}
}
