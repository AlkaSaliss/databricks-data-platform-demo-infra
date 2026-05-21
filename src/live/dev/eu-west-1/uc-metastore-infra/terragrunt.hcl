terraform {
  source = "../../../../modules/uc-metastore-infra"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

dependency "account_admin" {
  config_path = "../account-admin"

  mock_outputs = {
    admin_group = {
      display_name = "mock-admin-group"
    }
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
}

inputs = {
  region                   = include.region.locals.aws_region
  prefix                   = "uc-${include.env.locals.environment}-${include.region.locals.aws_region}"
  metastore_name           = "metastore"
  databricks_account_id    = include.env.locals.databricks_account_id
  databricks_client_id     = include.env.locals.databricks_client_id
  databricks_client_secret = include.env.locals.databricks_client_secret
  unity_metastore_owner    = dependency.account_admin.outputs.admin_group.display_name
}
