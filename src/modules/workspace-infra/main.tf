data "databricks_aws_assume_role_policy" "this" {
  provider    = databricks.mws
  external_id = var.databricks_account_id
}

resource "aws_iam_role" "cross_account_role" {
  name               = "${var.prefix}-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = var.tags
}

data "databricks_aws_crossaccount_policy" "this" {
  provider = databricks.mws
}

data "aws_iam_policy_document" "cross_account" {
  source_policy_documents = [data.databricks_aws_crossaccount_policy.this.json]

  statement {
    sid       = "allowPassCrossServiceRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = var.roles_to_assume
  }
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "${var.prefix}-policy"
  role   = aws_iam_role.cross_account_role.id
  policy = data.aws_iam_policy_document.cross_account.json
}

resource "aws_s3_bucket" "root_storage_bucket" {
  bucket        = "${var.prefix}-rootbucket"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-rootbucket"
  })
}

resource "aws_s3_bucket_versioning" "root_storage_bucket" {
  bucket = aws_s3_bucket.root_storage_bucket.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "root_storage_bucket" {
  bucket = aws_s3_bucket.root_storage_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "root_storage_bucket" {
  bucket                  = aws_s3_bucket.root_storage_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "databricks_aws_bucket_policy" "root_storage_bucket" {
  provider = databricks.mws
  bucket   = aws_s3_bucket.root_storage_bucket.bucket
}

resource "aws_s3_bucket_policy" "root_storage_bucket" {
  bucket     = aws_s3_bucket.root_storage_bucket.id
  policy     = data.databricks_aws_bucket_policy.root_storage_bucket.json
  depends_on = [aws_s3_bucket_public_access_block.root_storage_bucket]
}

resource "time_sleep" "wait_for_iam_propagation" {
  depends_on      = [aws_iam_role_policy.cross_account]
  create_duration = "30s"
}

resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  role_arn         = aws_iam_role.cross_account_role.arn
  credentials_name = "${var.prefix}-creds"
  depends_on       = [time_sleep.wait_for_iam_propagation]
}

resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${var.prefix}-network"
  security_group_ids = var.security_group_ids
  subnet_ids         = var.subnet_ids
  vpc_id             = var.vpc_id
}

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  bucket_name                = aws_s3_bucket.root_storage_bucket.bucket
  storage_configuration_name = "${var.prefix}-storage"
}

resource "databricks_mws_workspaces" "this" {
  provider       = databricks.mws
  account_id     = var.databricks_account_id
  aws_region     = var.region
  workspace_name = coalesce(var.workspace_name, var.prefix)

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}

resource "databricks_metastore_assignment" "default_metastore" {
  provider             = databricks.mws
  workspace_id         = databricks_mws_workspaces.this.workspace_id
  metastore_id         = var.metastore_id
  default_catalog_name = "hive_metastore"
}

resource "time_sleep" "wait_for_identity_federation" {
  depends_on      = [databricks_metastore_assignment.default_metastore]
  create_duration = "30s"
}

resource "databricks_mws_permission_assignment" "add_ws_admin_group" {
  depends_on   = [time_sleep.wait_for_identity_federation]
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = var.admin_group_id
  permissions  = ["ADMIN"]
}

data "databricks_user" "ws_user_data" {
  for_each  = toset(var.ws_users)
  user_name = each.value
  provider  = databricks.mws
}

resource "databricks_mws_permission_assignment" "assign_ws_users" {
  depends_on   = [time_sleep.wait_for_identity_federation]
  for_each     = data.databricks_user.ws_user_data
  provider     = databricks.mws
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = each.value.id
  permissions  = ["USER"]
}

data "aws_caller_identity" "current" {}

locals {
  databricks_workspace_url  = databricks_mws_workspaces.this.workspace_url
  databricks_workspace_host = startswith(local.databricks_workspace_url, "https://") ? local.databricks_workspace_url : "https://${local.databricks_workspace_url}"
  lakehouse_prefix          = coalesce(var.lakehouse_prefix, var.prefix)
  streaming_lake_role_name  = "${local.lakehouse_prefix}-uc-streaming-lake-access"
  streaming_lake_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.streaming_lake_role_name}"
  storage_credential_name   = replace("${local.lakehouse_prefix}-streaming-lake", "-", "_")
  external_location_name    = replace("${local.lakehouse_prefix}-streaming-lake", "-", "_")
  external_location_url     = "s3://${var.streaming_lake_bucket_name}/"
}

resource "databricks_catalog" "energy_market" {
  depends_on = [databricks_mws_permission_assignment.add_ws_admin_group]

  name          = var.lakehouse_catalog_name
  comment       = "Energy market demo lakehouse catalog managed by Terraform."
  force_destroy = true
}

resource "databricks_schema" "bronze" {
  catalog_name  = databricks_catalog.energy_market.name
  name          = var.lakehouse_bronze_schema_name
  comment       = "Raw and externally mounted streaming lake data."
  force_destroy = true
}

resource "databricks_schema" "silver" {
  catalog_name  = databricks_catalog.energy_market.name
  name          = var.lakehouse_silver_schema_name
  comment       = "Normalized France Eco2mix snapshot tables."
  force_destroy = true
}

resource "databricks_schema" "gold" {
  catalog_name  = databricks_catalog.energy_market.name
  name          = var.lakehouse_gold_schema_name
  comment       = "Curated KPI tables for the energy market demo."
  force_destroy = true
}

resource "databricks_storage_credential" "streaming_lake" {
  name      = local.storage_credential_name
  comment   = "Unity Catalog credential for the Flink streaming lake bucket."
  read_only = true

  aws_iam_role {
    role_arn = local.streaming_lake_role_arn
  }

  depends_on = [databricks_mws_permission_assignment.add_ws_admin_group]
}

data "databricks_aws_unity_catalog_assume_role_policy" "streaming_lake" {
  aws_account_id = data.aws_caller_identity.current.account_id
  role_name      = local.streaming_lake_role_name
  external_id    = databricks_storage_credential.streaming_lake.aws_iam_role[0].external_id
}

resource "aws_iam_policy" "streaming_lake_uc_access" {
  name        = "${local.streaming_lake_role_name}-policy"
  description = "Read-only Unity Catalog access to the Flink streaming lake bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = var.streaming_lake_bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.streaming_lake_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = local.streaming_lake_role_arn
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.streaming_lake_role_name}-policy"
  })
}

resource "aws_iam_role" "streaming_lake_uc_access" {
  name               = local.streaming_lake_role_name
  assume_role_policy = data.databricks_aws_unity_catalog_assume_role_policy.streaming_lake.json

  tags = merge(var.tags, {
    Name = local.streaming_lake_role_name
  })
}

resource "aws_iam_role_policy_attachment" "streaming_lake_uc_access" {
  role       = aws_iam_role.streaming_lake_uc_access.name
  policy_arn = aws_iam_policy.streaming_lake_uc_access.arn
}

resource "time_sleep" "wait_for_streaming_lake_iam" {
  depends_on      = [aws_iam_role_policy_attachment.streaming_lake_uc_access]
  create_duration = "30s"
}

resource "databricks_external_location" "streaming_lake" {
  name            = local.external_location_name
  url             = local.external_location_url
  credential_name = databricks_storage_credential.streaming_lake.id
  comment         = "External location for Flink streaming lake files."
  read_only       = true

  depends_on = [time_sleep.wait_for_streaming_lake_iam]
}

resource "databricks_volume" "streaming_lake" {
  catalog_name     = databricks_catalog.energy_market.name
  schema_name      = databricks_schema.bronze.name
  name             = var.streaming_lake_volume_name
  volume_type      = "EXTERNAL"
  storage_location = local.external_location_url
  comment          = "External volume exposing the Flink streaming lake bucket."

  depends_on = [databricks_external_location.streaming_lake]
}
