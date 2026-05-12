# Provider configuration for the Databricks workspace infrastructure module

# Databricks provider configuration
# This provider is aliased as 'mws' for account-level operations
# Note: Provider requirements are now consolidated in versions.tf

# Note: The provider configuration should be done in the root module
# The following is an example of how to configure the provider:

# provider "databricks" {
#   alias      = "mws"
#   host       = "https://accounts.cloud.databricks.com"
#   account_id = var.databricks_account_id
#   client_id  = var.databricks_client_id
#   client_secret = var.databricks_client_secret
# }
