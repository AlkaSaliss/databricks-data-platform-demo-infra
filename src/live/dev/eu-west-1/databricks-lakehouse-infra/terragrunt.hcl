terraform {
  source = "../../../../modules/databricks-lakehouse-infra"
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

dependency "workspace" {
  config_path = "../workspace-infra"

  mock_outputs = {
    databricks_workspace_url = "mock-workspace.cloud.databricks.com"
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
}

dependency "streaming_lake" {
  config_path = "../streaming-lake-infra"

  mock_outputs = {
    bronze_bucket_name = "mock-streaming-bronze"
    bronze_bucket_arn  = "arn:aws:s3:::mock-streaming-bronze"
  }

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
}

inputs = {
  prefix                     = "energy-market-demo-${include.env.locals.environment}-${include.region.locals.aws_region}"
  databricks_account_id      = include.env.locals.databricks_account_id
  databricks_host            = format("https://%s", dependency.workspace.outputs.databricks_workspace_url)
  databricks_client_id       = include.env.locals.databricks_client_id
  databricks_client_secret   = include.env.locals.databricks_client_secret
  streaming_lake_bucket_name = dependency.streaming_lake.outputs.bronze_bucket_name
  streaming_lake_bucket_arn  = dependency.streaming_lake.outputs.bronze_bucket_arn
}
