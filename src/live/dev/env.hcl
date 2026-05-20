# Environment-specific configuration for development
locals {
  environment      = "dev"
  aws_profile_name = get_env("AWS_PROFILE_NAME", "default")
  owner_email      = get_env("DATABRICKS_OWNER_EMAIL", "")
  default_tags = {
    Project = "databricks-data-platform-demo-infra"
    Owner   = local.owner_email
  }
  databricks_account_id      = get_env("DATABRICKS_ACCOUNT_ID", "")
  databricks_client_id       = get_env("DATABRICKS_CLIENT_ID", "")
  databricks_client_secret   = get_env("DATABRICKS_CLIENT_SECRET", "")
  databricks_owner_email     = get_env("DATABRICKS_OWNER_EMAIL", "")
  unity_admin_group          = get_env("UNITY_ADMIN_GROUP", "Unity Catalog Admins")
  unity_users_group          = get_env("UNITY_USERS_GROUP", "Unity Catalog Users")
  confluent_cloud_api_key    = get_env("CONFLUENT_CLOUD_API_KEY", "")
  confluent_cloud_api_secret = get_env("CONFLUENT_CLOUD_API_SECRET", "")
}
