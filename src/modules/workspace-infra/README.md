# Workspace Infrastructure Module

This Terraform module creates the complete AWS infrastructure required for Databricks Unity Catalog, including:

- VPC with public and private subnets
- VPC endpoints for S3, STS, and Kinesis
- S3 buckets for workspace root storage and Unity Catalog metastore
- IAM roles and policies for cross-account access and Unity Catalog
- Databricks workspace configuration
- Unity Catalog metastore setup and assignment

## Features

- **Complete Infrastructure**: Creates all necessary AWS resources for Unity Catalog
- **Security Best Practices**: Implements proper IAM roles, bucket policies, and VPC security
- **Unity Catalog Ready**: Automatically sets up metastore and assigns it to the workspace
- **Configurable**: Supports custom naming, tagging, and configuration options

## Usage

```hcl
module "workspace_infra" {
  source = "./modules/workspace-infra"

  # Required variables
  prefix                   = "my-databricks"
  region                   = "us-west-2"
  cidr_block              = "10.0.0.0/16"
  databricks_account_id   = "12345678-1234-1234-1234-123456789012"
  unity_metastore_owner   = "admin@company.com"

  # Optional variables
  workspace_name          = "My Databricks Workspace"
  metastore_name         = "my-metastore"
  tags = {
    Environment = "dev"
    Project     = "databricks-unity-catalog"
  }

  providers = {
    databricks.mws = databricks.mws
  }
}
```

## Requirements

| Name | Version |
|------|------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| databricks | >= 1.29.0 |

## Providers

| Name | Version |
|------|------|
| aws | >= 5.0 |
| databricks.mws | >= 1.29.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| prefix | Prefix to name the resources created by this module | `string` | n/a | yes |
| region | AWS region where the assets will be deployed | `string` | n/a | yes |
| cidr_block | CIDR block for the VPC that will be used to create the Databricks workspace | `string` | n/a | yes |
| databricks_account_id | Databricks Account ID | `string` | n/a | yes |
| unity_metastore_owner | Name of the principal that will be the owner of the Metastore | `string` | n/a | yes |
| workspace_name | Workspace Name for this module - if none are provided, the prefix will be used | `string` | `""` | no |
| metastore_name | Name of the metastore that will be created | `string` | `null` | no |
| tags | List of tags to be propagated across all assets in this module | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| security_group_ids | Security group ID for DB Compliant VPC |
| subnets | Private subnets for workspace creation |
| root_bucket | Root storage bucket name |
| metastore_bucket | Unity Catalog metastore bucket name |
| cross_account_role_arn | AWS Cross account role ARN |
| unity_catalog_iam_role_arn | Unity Catalog metastore data access IAM role ARN |
| databricks_workspace_id | Databricks workspace ID |
| databricks_workspace_url | Databricks workspace URL |
| unity_catalog_metastore_id | Unity Catalog Metastore ID |
| unity_catalog_metastore_name | Unity Catalog Metastore Name |

## Resources Created

### AWS Resources
- VPC with public and private subnets
- Internet Gateway and NAT Gateway
- VPC Endpoints (S3, STS, Kinesis)
- S3 buckets (root storage and metastore)
- IAM roles and policies
- Security groups

### Databricks Resources
- Workspace credentials
- Network configuration
- Storage configuration
- Workspace
- Unity Catalog metastore
- Metastore data access configuration
- Metastore assignment to workspace

## Notes

- This module requires the Databricks provider to be configured with account-level credentials
- The Unity Catalog metastore owner should be a valid Databricks user or group
- S3 bucket names must be globally unique, so the prefix should be unique
- The module creates resources that may incur AWS charges
