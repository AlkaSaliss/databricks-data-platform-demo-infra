terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    databricks = {
      source                = "databricks/databricks"
      version               = ">= 1.29.0"
      configuration_aliases = [databricks.mws]
    }

    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}
