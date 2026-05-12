# Unity Catalog AWS Infrastructure Deployment Guide

This guide walks you through deploying the Unity Catalog AWS Infrastructure using Terragrunt.

## Prerequisites

### 1. Tools Installation
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.45
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials

### 2. Databricks Setup
- Databricks account with admin privileges
- Service Principal created in Databricks account console
- Service Principal must have account admin permissions

### 3. AWS Permissions
Your AWS credentials must have permissions to create:
- VPCs, subnets, security groups
- S3 buckets and bucket policies
- IAM roles and policies
- VPC endpoints

## Step-by-Step Deployment

### Step 1: Deploy Terraform State Infrastructure

First, deploy the state infrastructure:

```bash
cd ../terraform-state-infra

# Set required environment variables
export TF_STATE_BUCKET="your-unique-terraform-state-bucket-name"
export TF_STATE_DYNAMODB_TABLE="your-terraform-state-lock-table"

# Deploy
terragrunt apply
```

### Step 2: Configure Variables

1. **Navigate to the component directory**:
   ```bash
   cd live/dev/eu-west-1/workspace-infra
   ```

2. **Edit the `terraform.tfvars` file** with your actual values:
   ```bash
   vim terraform.tfvars
   ```
   
   Update the file with your configuration:
   ```hcl
   # Required variables
   prefix                   = "your-company-dev-eu-west-1"
   region                   = "eu-west-1"
   cidr_block              = "10.0.0.0/16"
   databricks_account_id    = "your-databricks-account-id"
   unity_metastore_owner    = "admin@yourcompany.com"
   databricks_client_id     = "your-service-principal-client-id"
   databricks_client_secret = "your-service-principal-client-secret"
   
   # Optional variables
   workspace_name = "Unity-Catalog-Workspace"
   metastore_name = "dev-metastore"
   
   # Tags
   tags = {
     Environment = "dev"
     Project     = "databricks-unity-catalog"
     ManagedBy   = "terragrunt"
     Region      = "eu-west-1"
     Owner       = "admin@yourcompany.com"
   }
   ```

### Step 3: Deploy Unity Catalog Infrastructure

```bash
# Initialize Terragrunt
terragrunt init

# Review the plan
terragrunt plan

# Apply the configuration
terragrunt apply
```

### Step 5: Verify Deployment

After successful deployment:

```bash
# View outputs
terragrunt output

# Get workspace URL
terragrunt output databricks_workspace_url
```

## Post-Deployment Configuration

### Access Your Workspace

1. Navigate to the workspace URL from the output
2. Log in with your Databricks account credentials
3. Verify Unity Catalog is enabled in the workspace

### Verify Unity Catalog Setup

1. In the Databricks workspace, go to **Data** > **Catalogs**
2. You should see the `hive_metastore` catalog
3. Check that the metastore is properly assigned

## Troubleshooting

### Common Issues

#### 1. S3 Bucket Name Already Exists
```
Error: Error creating S3 bucket: BucketAlreadyExists
```
**Solution**: Change the `DATABRICKS_PREFIX` to something unique.

#### 2. Databricks Authentication Failed
```
Error: cannot authenticate Databricks
```
**Solution**: 
- Verify `DATABRICKS_ACCOUNT_ID` is correct
- Ensure service principal has account admin permissions
- Check `DATABRICKS_CLIENT_ID` and `DATABRICKS_CLIENT_SECRET`

#### 3. AWS Permissions Error
```
Error: AccessDenied: User is not authorized to perform
```
**Solution**: Ensure your AWS credentials have the required permissions listed in prerequisites.

#### 4. VPC CIDR Conflicts
```
Error: InvalidVpc.Range: The CIDR '10.0.0.0/16' conflicts with another subnet
```
**Solution**: Change the `cidr_block` in `terragrunt.hcl` to a different range.

### Debug Mode

Enable debug logging:
```bash
export TF_LOG=DEBUG
terragrunt apply
```

### State Issues

If you encounter state-related issues:
```bash
# Refresh state
terragrunt refresh

# Import existing resources (if needed)
terragrunt import <resource_type>.<resource_name> <resource_id>
```

## Cleanup

To destroy the infrastructure:

```bash
# Destroy Unity Catalog infrastructure
terragrunt destroy

# Destroy state infrastructure (optional)
cd ../terraform-state-infra
terragrunt destroy
```

**Warning**: This will permanently delete all resources including S3 buckets and their contents.

## Security Considerations

1. **Environment Variables**: Never commit `.env` files to version control
2. **State Files**: Ensure state files are stored securely in S3 with encryption
3. **IAM Roles**: Follow principle of least privilege for all IAM roles
4. **S3 Buckets**: All buckets are created with public access blocked
5. **VPC**: Private subnets are used for Databricks compute resources

## Next Steps

After successful deployment:

1. **Configure Users and Groups**: Set up Databricks users and groups
2. **Create Catalogs**: Create additional Unity Catalog catalogs as needed
3. **Set Up Data Sources**: Configure external data sources
4. **Implement Governance**: Set up data governance policies
5. **Monitor Usage**: Set up monitoring and alerting

## Support

For issues:
1. Check the troubleshooting section above
2. Review Terraform and Terragrunt logs
3. Consult Databricks documentation for Unity Catalog
4. Check AWS documentation for infrastructure components
