# Terragrunt configuration for Databricks Account Admin deployment

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  source = "../../../../modules/account-admin"
}

inputs = {
  databricks_account_id    = include.env.locals.databricks_account_id
  databricks_client_id     = include.env.locals.databricks_client_id
  databricks_client_secret = include.env.locals.databricks_client_secret
  account_owner_email      = include.env.locals.databricks_owner_email
}
