# Root root.hcl - Common configuration for all environments

locals {
  # Common tags to apply to all resources
  # Parse environment from directory structure
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  aws_region  = local.region_vars.locals.aws_region
  component   = basename(get_terragrunt_dir())
  common_tags = merge(
    lookup(local.environment_vars.locals, "default_tags", {}),
    {
      ManagedBy   = "terragrunt"
      Environment = local.environment
      Region      = local.aws_region
      Component   = local.component
    }
  )
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "dbx-terraform-state-${local.environment}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "dbx-terraform-locks-${local.environment}"

    # Enable versioning and server-side encryption
    s3_bucket_tags = merge(local.common_tags, {
      Name = "dbx-terraform-state-${local.environment}-${local.aws_region}"
    })

    dynamodb_table_tags = merge(local.common_tags, {
      Name = "dbx-terraform-locks-${local.environment}"
    })
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}

${contains(["terraform-state-infra", "network-infra"], local.component) ? "" : <<EOT
provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
  client_id  = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
EOT
}
EOF
}

# Configure retry and error handling
retry_max_attempts       = 3
retry_sleep_interval_sec = 5

# Terragrunt will copy the Terraform configurations specified by the source parameter
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()

    optional_var_files = [
      find_in_parent_folders("account.tfvars", "ignore"),
      find_in_parent_folders("region.tfvars", "ignore"),
      find_in_parent_folders("env.tfvars", "ignore")
    ]
  }

  extra_arguments "disable_input" {
    commands  = get_terraform_commands_that_need_input()
    arguments = ["-input=false"]
  }

  extra_arguments "parallelism" {
    commands  = ["apply", "plan", "destroy"]
    arguments = ["-parallelism=10"]
  }
}

# Input validation
inputs = {
  environment = local.environment
  aws_region  = local.aws_region
}
