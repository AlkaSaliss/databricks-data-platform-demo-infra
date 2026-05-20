data "aws_caller_identity" "current" {}

locals {
  metastore_name = var.metastore_name == null ? "${var.prefix}-metastore" : var.metastore_name
  iam_role_name  = "${var.prefix}-unity-catalog-metastore-access"
  iam_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.iam_role_name}"
}

resource "aws_s3_bucket" "metastore" {
  bucket        = "${var.prefix}-metastore"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-metastore"
  })
}

resource "aws_s3_bucket_versioning" "metastore" {
  bucket = aws_s3_bucket.metastore.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metastore" {
  bucket = aws_s3_bucket.metastore.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "metastore" {
  bucket                  = aws_s3_bucket.metastore.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "metastore_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::414351767826:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
      ]
    }
  }

  statement {
    sid     = "ExplicitSelfRoleAssumption"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = [local.iam_role_arn]
    }
  }
}

resource "aws_iam_policy" "metastore" {
  name = "${var.prefix}-unity-catalog-metastore-access-iam-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.prefix}-databricks-unity-metastore"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.metastore.arn,
          "${aws_s3_bucket.metastore.arn}/*"
        ]
        Effect = "Allow"
      },
      {
        Action   = ["sts:AssumeRole"]
        Resource = [local.iam_role_arn]
        Effect   = "Allow"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.iam_role_name} IAM policy"
  })
}

resource "aws_iam_policy" "sample_data" {
  name = "${var.prefix}-unity-catalog-sample-data-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.prefix}-databricks-sample-data"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::databricks-datasets-oregon/*",
          "arn:aws:s3:::databricks-datasets-oregon"
        ]
        Effect = "Allow"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.prefix}-unity-catalog IAM policy"
  })
}

resource "aws_iam_role" "metastore_data_access" {
  name                = local.iam_role_name
  assume_role_policy  = data.aws_iam_policy_document.metastore_assume_role.json
  managed_policy_arns = [aws_iam_policy.metastore.arn, aws_iam_policy.sample_data.arn]

  tags = merge(var.tags, {
    Name = local.iam_role_name
  })
}

resource "time_sleep" "wait_for_iam_propagation" {
  depends_on      = [aws_iam_role.metastore_data_access]
  create_duration = "30s"
}

resource "databricks_metastore" "this" {
  provider      = databricks.mws
  name          = local.metastore_name
  region        = var.region
  owner         = var.unity_metastore_owner
  storage_root  = "s3://${aws_s3_bucket.metastore.id}/metastore"
  force_destroy = true
}

resource "databricks_metastore_data_access" "default" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.this.id
  name         = "${var.prefix}-metastore-root-access"
  is_default   = true

  aws_iam_role {
    role_arn = aws_iam_role.metastore_data_access.arn
  }

  depends_on = [time_sleep.wait_for_iam_propagation]
}
