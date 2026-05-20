data "aws_caller_identity" "current" {}

locals {
  iam_role_name             = "${var.prefix}-uc-streaming-lake-access"
  iam_role_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.iam_role_name}"
  storage_credential_name   = replace("${var.prefix}-streaming-lake", "-", "_")
  external_location_name    = replace("${var.prefix}-streaming-lake", "-", "_")
  external_location_url     = "s3://${var.streaming_lake_bucket_name}/"
  raw_fr_energy_grid_prefix = "bronze/raw_fr_energy_grid/"
}

resource "databricks_catalog" "energy_market" {
  name          = var.catalog_name
  comment       = "Energy market demo lakehouse catalog managed by Terraform."
  force_destroy = true
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.energy_market.name
  name         = var.bronze_schema_name
  comment      = "Raw and externally mounted streaming lake data."
}

resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.energy_market.name
  name         = var.silver_schema_name
  comment      = "Normalized France Eco2mix snapshot tables."
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.energy_market.name
  name         = var.gold_schema_name
  comment      = "Curated KPI tables for the energy market demo."
}

resource "databricks_storage_credential" "streaming_lake" {
  name      = local.storage_credential_name
  comment   = "Unity Catalog credential for the Flink streaming lake bucket."
  read_only = true

  aws_iam_role {
    role_arn = local.iam_role_arn
  }
}

data "databricks_aws_unity_catalog_assume_role_policy" "streaming_lake" {
  aws_account_id = data.aws_caller_identity.current.account_id
  role_name      = local.iam_role_name
  external_id    = databricks_storage_credential.streaming_lake.aws_iam_role[0].external_id
}

resource "aws_iam_policy" "streaming_lake" {
  name        = "${local.iam_role_name}-policy"
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
        Resource = local.iam_role_arn
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.iam_role_name}-policy"
  })
}

resource "aws_iam_role" "streaming_lake" {
  name               = local.iam_role_name
  assume_role_policy = data.databricks_aws_unity_catalog_assume_role_policy.streaming_lake.json

  tags = merge(var.tags, {
    Name = local.iam_role_name
  })
}

resource "aws_iam_role_policy_attachment" "streaming_lake" {
  role       = aws_iam_role.streaming_lake.name
  policy_arn = aws_iam_policy.streaming_lake.arn
}

resource "time_sleep" "wait_for_iam" {
  depends_on      = [aws_iam_role_policy_attachment.streaming_lake]
  create_duration = "30s"
}

resource "databricks_external_location" "streaming_lake" {
  name            = local.external_location_name
  url             = local.external_location_url
  credential_name = databricks_storage_credential.streaming_lake.id
  comment         = "External location for Flink streaming lake files."
  read_only       = true

  depends_on = [time_sleep.wait_for_iam]
}

resource "databricks_volume" "streaming_lake" {
  catalog_name     = databricks_catalog.energy_market.name
  schema_name      = databricks_schema.bronze.name
  name             = var.volume_name
  volume_type      = "EXTERNAL"
  storage_location = local.external_location_url
  comment          = "External volume exposing the Flink streaming lake bucket."

  depends_on = [databricks_external_location.streaming_lake]
}
