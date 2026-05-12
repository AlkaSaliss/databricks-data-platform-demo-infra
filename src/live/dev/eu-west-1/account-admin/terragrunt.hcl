# Terragrunt configuration for Databricks Account Admin deployment

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/account-admin"
}

inputs = {}