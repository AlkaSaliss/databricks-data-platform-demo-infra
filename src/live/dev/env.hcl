# Environment-specific configuration for development
locals {
  environment              = "dev"
  aws_profile_name         = get_env("AWS_PROFILE_NAME", "default")
  owner_email              = get_env("DATABRICKS_OWNER_EMAIL", "")
  default_tags = {
    Project = "databricks-data-platform-demo-infra"
    Owner   = local.owner_email
  }
  databricks_account_id    = get_env("DATABRICKS_ACCOUNT_ID", "")
  databricks_client_id     = get_env("DATABRICKS_CLIENT_ID", "")
  databricks_client_secret = get_env("DATABRICKS_CLIENT_SECRET", "")
  databricks_owner_email   = get_env("DATABRICKS_OWNER_EMAIL", "")
}
