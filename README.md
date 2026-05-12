# Databricks Workspace Infrastructure as Code

This project provides Terraform modules and Terragrunt configurations to deploy Databricks workspaces on AWS, with a focus on Unity Catalog setup.

## Overview

The infrastructure is organized into reusable Terraform modules and environment-specific Terragrunt configurations. This allows for consistent deployments across multiple environments (e.g., dev, staging, prod) and regions.

## Modules

This project contains the following core Terraform modules:

- **[Account Admin (`account-admin`)](./doc/account-admin.md)**: Manages Databricks account-level resources such as users, groups, and service principals. This is typically the first module to be deployed to set up account-level prerequisites.
- **[Terraform State Infrastructure (`terraform-state-infra`)](./doc/terraform-state-infra.md)**: Provisions the S3 bucket and DynamoDB table required for managing Terraform's remote state and state locking. This module should be deployed once per AWS account/region where you intend to manage Terraform state.
- **`network-infra`**: Deploys the AWS network baseline needed by the Databricks workspace.
- **`uc-metastore-infra`**: Deploys the Unity Catalog metastore resources across AWS and Databricks.
- **`workspace-infra`**: Deploys the Databricks workspace and its related AWS integration resources.

## Project Structure

```
.
├── Makefile             # Makefile with common commands for deployment and management
├── README.md            # This file
├── doc/                 # Directory containing detailed documentation for each module
│   ├── account-admin.md
│   ├── terraform-state-infra.md
└── src/
    ├── environments/    # Terragrunt configurations for different environments (e.g., dev, staging, prod)
    │   └── dev/
    │       └── eu-west-1/ # Region-specific configurations
    │           ├── account-admin/
    │           │   └── terragrunt.hcl
    │           ├── network-infra/
    │           │   └── terragrunt.hcl
    │           ├── uc-metastore-infra/
    │           │   └── terragrunt.hcl
    │           ├── workspace-infra/
    │           │   └── terragrunt.hcl
    │           ├── env.hcl
    │           └── region.hcl
    ├── modules/         # Reusable Terraform modules
    │   ├── account-admin/
    │   ├── terraform-state-infra/
    │   ├── network-infra/
    │   ├── uc-metastore-infra/
    │   └── workspace-infra/
    ├── root.hcl         # Root Terragrunt configuration, included by environment configurations
    └── versions.tf      # Terraform provider versions
```

## Getting Started

1.  **Prerequisites**: Ensure you have Terraform, Terragrunt, and AWS CLI installed and configured.
2.  **Configure Backend**: Deploy the `terraform-state-infra` module (or ensure you have an S3 backend and DynamoDB table ready).
3.  **Set Environment Variables**: Export necessary environment variables for Databricks authentication (e.g., `DATABRICKS_ACCOUNT_ID`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET`).
4.  **Review `env.hcl` and `region.hcl`**: Update these files in your target environment directory (e.g., `src/environments/dev/eu-west-1/`) with appropriate values.
5.  **Update `terraform.tfvars`**: For each component in your environment (e.g., `src/environments/dev/eu-west-1/account-admin/terraform.tfvars`), copy the `.tfvars.example` file if it exists and populate it with your specific inputs.
6.  **Use Makefile**: The provided `Makefile` contains convenient targets for initializing, planning, and applying the configurations. 
    Example commands:
    ```bash
    # Show help
    make help

    # Initialize a specific component in dev/eu-west-1
    make init ENV=dev REGION=eu-west-1 COMPONENT=account-admin

    # Plan a component (defaults to dev/eu-west-1/account-admin if not specified)
    make plan COMPONENT=workspace-infra

    # Apply all components in dev
    make dev-apply-all REGION=eu-west-1
    ```

Refer to the individual module documentation in the `doc/` folder for more details on each module's purpose, resources, and variables.
