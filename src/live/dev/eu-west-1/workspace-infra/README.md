# Unity Catalog AWS Infrastructure - Dev Environment

This Terragrunt configuration deploys the Unity Catalog AWS Infrastructure module in the dev environment for the eu-west-1 region.

## Prerequisites

1. **Terraform State Infrastructure**: The `terraform-state-infra` component must be deployed first
2. **AWS Credentials**: Configure AWS credentials with appropriate permissions
3. **Databricks Account**: Valid Databricks account with service principal credentials
4. **Environment Variables**: Set required environment variables (see `.env.example`)

## Setup

1. **Configure Variables**: Update the `terraform.tfvars` file with your actual values:
   ```bash
   # Edit terraform.tfvars with your actual values
   vim terraform.tfvars
   ```

   The file should contain variables like:
   ```hcl
   prefix                   = "your-prefix"
   region                   = "eu-west-1"
   cidr_block              = "10.0.0.0/16"
   databricks_account_id    = "your-databricks-account-id"
   unity_metastore_owner    = "your-email@example.com"
   databricks_client_id     = "your-databricks-client-id"
   databricks_client_secret = "your-databricks-client-secret"
   workspace_name           = "your-workspace-name"
   metastore_name          = "your-metastore-name"
   ```

## Deployment

1. **Initialize Terragrunt**:
   ```bash
   terragrunt init
   ```

2. **Plan the deployment**:
   ```bash
   terragrunt plan
   ```

3. **Apply the configuration**:
   ```bash
   terragrunt apply
   ```

## What Gets Created

This configuration creates:

### AWS Infrastructure
- VPC with public and private subnets in eu-west-1
- Internet Gateway and NAT Gateway
- VPC Endpoints for S3, STS, and Kinesis
- S3 buckets for root storage and Unity Catalog metastore
- IAM roles and policies for Databricks cross-account access
- Security groups with appropriate rules

### Databricks Resources
- Databricks workspace in eu-west-1
- Unity Catalog metastore
- Metastore data access configuration
- Metastore assignment to the workspace

## Outputs

After successful deployment, you can view outputs:

```bash
terragrunt output
```

Key outputs include:
- `databricks_workspace_url`: URL to access the Databricks workspace
- `databricks_workspace_id`: Workspace ID for further configuration
- `unity_catalog_metastore_id`: Metastore ID for Unity Catalog

## Cleanup

To destroy the infrastructure:

```bash
terragrunt destroy
```

**Note**: This will delete all resources including S3 buckets and their contents.

## Troubleshooting

### Common Issues

1. **S3 Bucket Name Conflicts**: If you get bucket name conflicts, change the `DATABRICKS_PREFIX` to something unique

2. **Databricks Authentication**: Ensure your service principal has account admin permissions

3. **AWS Permissions**: Ensure your AWS credentials have permissions to create VPCs, S3 buckets, and IAM roles

4. **Region Availability**: Ensure Databricks is available in eu-west-1 for your account

### Logs

Enable detailed logging:
```bash
export TF_LOG=DEBUG
terragrunt apply
```

## Dependencies

This component depends on:
- `../terraform-state-infra`: Must be deployed first to create the Terraform state backend

## Configuration

The configuration uses:
- **CIDR Block**: `10.0.0.0/16` for the VPC
- **Region**: `eu-west-1`
- **Environment**: `dev`
- **Subnets**: Automatically calculated from CIDR block

To modify these settings, update the `inputs` section in `terragrunt.hcl`.