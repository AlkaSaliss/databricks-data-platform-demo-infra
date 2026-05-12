# Terragrunt configuration for S3 state bucket and DynamoDB table

# Override backend for state bucket creation - it will use local backend
# This module creates the S3 bucket, so it should use a local backend for its own state.
remote_state {
  backend = "local"
  config  = {}
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt" # Ensure local backend config is written for this module
  }
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../../modules/terraform-state-infra"
}

# Prevent destruction of state resources
prevent_destroy = true


inputs = {
  bucket_name         = get_env("TF_STATE_BUCKET") == "" ? error("ERROR: TF_STATE_BUCKET environment variable must be set") : get_env("TF_STATE_BUCKET")
  dynamodb_table_name = get_env("TF_STATE_DYNAMODB_TABLE") == "" ? error("ERROR: TF_STATE_DYNAMODB_TABLE environment variable must be set") : get_env("TF_STATE_DYNAMODB_TABLE")
}