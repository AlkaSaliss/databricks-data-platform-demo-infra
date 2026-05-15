variable "prefix" {
  type        = string
  description = "(Required) Prefix used to name streaming lake resources."

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

variable "tags" {
  type        = map(string)
  description = "(Optional) Tags applied to streaming lake resources."
  default     = {}
}
