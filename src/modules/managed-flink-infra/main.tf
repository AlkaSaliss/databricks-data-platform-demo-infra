locals {
  application_name = "${var.prefix}-bronze"
  artifact_bucket  = "${var.prefix}-artifacts"
  artifact_key     = "applications/raw_fr_energy_grid_to_s3.zip"
  log_group_name   = "/aws/kinesis-analytics/${local.application_name}"
  log_stream_name  = "application"

  bronze_uri_without_scheme = trimprefix(var.s3_bronze_uri, "s3://")
  bronze_uri_parts          = split("/", local.bronze_uri_without_scheme)
  bronze_bucket_name        = local.bronze_uri_parts[0]
  bronze_prefix             = join("/", slice(local.bronze_uri_parts, 1, length(local.bronze_uri_parts)))
  bronze_bucket_arn         = "arn:aws:s3:::${local.bronze_bucket_name}"
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifact_bucket
  force_destroy = true

  tags = merge(var.tags, {
    Name = local.artifact_bucket
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "application_zip" {
  bucket      = aws_s3_bucket.artifacts.bucket
  key         = local.artifact_key
  source      = var.application_zip_path
  source_hash = filemd5(var.application_zip_path)

  depends_on = [
    aws_s3_bucket_versioning.artifacts
  ]
}

resource "aws_cloudwatch_log_group" "flink" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_stream" "flink" {
  name           = local.log_stream_name
  log_group_name = aws_cloudwatch_log_group.flink.name
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["kinesisanalytics.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flink" {
  name               = "${local.application_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "flink" {
  statement {
    sid = "ReadApplicationArtifact"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      "${aws_s3_bucket.artifacts.arn}/${local.artifact_key}",
    ]
  }

  statement {
    sid = "ListApplicationArtifactBucket"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.artifacts.arn,
    ]
  }

  statement {
    sid = "WriteBronzeObjects"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    resources = [
      "${local.bronze_bucket_arn}/${local.bronze_prefix}*",
    ]
  }

  statement {
    sid = "ListBronzeBucket"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [
      local.bronze_bucket_arn,
    ]
  }

  statement {
    sid = "WriteCloudWatchLogs"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      aws_cloudwatch_log_group.flink.arn,
      "${aws_cloudwatch_log_group.flink.arn}:log-stream:${aws_cloudwatch_log_stream.flink.name}",
    ]
  }
}

resource "aws_iam_role_policy" "flink" {
  name   = "${local.application_name}-policy"
  role   = aws_iam_role.flink.id
  policy = data.aws_iam_policy_document.flink.json
}

resource "aws_kinesisanalyticsv2_application" "bronze" {
  name                   = local.application_name
  runtime_environment    = "FLINK-1_19"
  service_execution_role = aws_iam_role.flink.arn
  start_application      = var.start_application

  application_configuration {
    application_code_configuration {
      code_content_type = "ZIPFILE"

      code_content {
        s3_content_location {
          bucket_arn     = aws_s3_bucket.artifacts.arn
          file_key       = aws_s3_object.application_zip.key
          object_version = aws_s3_object.application_zip.version_id
        }
      }
    }

    application_snapshot_configuration {
      snapshots_enabled = false
    }

    environment_properties {
      property_group {
        property_group_id = "kinesis.analytics.flink.run.options"

        property_map = {
          jarfile = "lib/pyflink-dependencies.jar"
          python  = "jobs/raw_fr_energy_grid_to_s3.py"
        }
      }

      property_group {
        property_group_id = "bronze-sink-config"

        property_map = {
          kafka_api_key           = var.kafka_api_key
          kafka_api_secret        = var.kafka_api_secret
          kafka_bootstrap_servers = var.kafka_bootstrap_servers
          kafka_group_id          = var.kafka_group_id
          kafka_topic             = var.kafka_topic
          s3_bronze_uri           = var.s3_bronze_uri
        }
      }
    }

    flink_application_configuration {
      checkpoint_configuration {
        configuration_type            = "CUSTOM"
        checkpointing_enabled         = true
        checkpoint_interval           = 60000
        min_pause_between_checkpoints = 30000
      }

      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level          = "INFO"
        metrics_level      = "APPLICATION"
      }

      parallelism_configuration {
        auto_scaling_enabled = false
        configuration_type   = "CUSTOM"
        parallelism          = 1
        parallelism_per_kpu  = 1
      }
    }
  }

  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.flink.arn
  }

  tags = merge(var.tags, {
    Name = local.application_name
  })

  depends_on = [
    aws_iam_role_policy.flink,
  ]
}
