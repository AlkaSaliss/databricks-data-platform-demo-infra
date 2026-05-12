# Variables for Databricks Account Admin Module

# Databricks Account Configuration
variable "databricks_client_id" {
  description = "Application ID of account-level service principal"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.databricks_client_id) > 0
    error_message = "Databricks client ID cannot be empty."
  }
}

variable "databricks_client_secret" {
  description = "Client secret of account-level service principal"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.databricks_client_secret) > 0
    error_message = "Databricks client secret cannot be empty."
  }
}

variable "databricks_account_id" {
  description = "Databricks Account ID"
  type        = string

  validation {
    condition     = can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", var.databricks_account_id))
    error_message = "Databricks account ID must be a valid UUID format."
  }
}

# User and Admin Configuration
variable "databricks_users" {
  description = <<EOT
  List of Databricks users to be added at account-level for Unity Catalog.
  Enter with square brackets and double quotes
  e.g ["first.last@domain.com", "second.last@domain.com"]
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.databricks_users : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All user emails must be valid email addresses."
  }
}

variable "account_owner_email" {
  description = "Email of the account owner"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.account_owner_email))
    error_message = "Account owner email must be a valid email address."
  }
}

variable "databricks_account_admins" {
  description = <<EOT
  List of Admins to be added at account-level for Unity Catalog.
  Enter with square brackets and double quotes
  e.g ["first.admin@domain.com", "second.admin@domain.com"]
  Note: Do not include the account owner in this list.
  EOT
  type        = list(string)

  validation {
    condition = alltrue([
      for email in var.databricks_account_admins : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All admin emails must be valid email addresses."
  }

  validation {
    condition     = length(var.databricks_account_admins) > 0
    error_message = "At least one account admin must be specified."
  }
}

variable "user_display_names" {
  description = "Map of user emails to display names"
  type        = map(string)
  default     = {}
}

# Group Configuration
variable "unity_admin_group" {
  description = "Name of the admin group. This group will be set as the owner of the Unity Catalog metastore"
  type        = string
  default     = "Unity Catalog Admins"

  validation {
    condition     = length(var.unity_admin_group) > 0 && length(var.unity_admin_group) <= 100
    error_message = "Unity admin group name must be between 1 and 100 characters."
  }
}

variable "unity_users_group" {
  description = "Name of the users group for regular Unity Catalog users"
  type        = string
  default     = "Unity Catalog Users"

  validation {
    condition     = length(var.unity_users_group) > 0 && length(var.unity_users_group) <= 100
    error_message = "Unity users group name must be between 1 and 100 characters."
  }
}

# Service Principal Configuration
variable "create_automation_service_principal" {
  description = "Whether to create a service principal for automation purposes"
  type        = bool
  default     = false
}

variable "automation_service_principal_name" {
  description = "Name of the automation service principal"
  type        = string
  default     = "terraform-automation-sp"

  validation {
    condition     = length(var.automation_service_principal_name) > 0 && length(var.automation_service_principal_name) <= 100
    error_message = "Service principal name must be between 1 and 100 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}
