locals {
  bronze_bucket_name = "${var.prefix}-streaming-bronze"
  raw_fr_prefix      = "bronze/raw_fr_energy_grid/"
}

resource "aws_s3_bucket" "bronze" {
  bucket        = local.bronze_bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Name = local.bronze_bucket_name
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bronze" {
  bucket = aws_s3_bucket.bronze.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bronze" {
  bucket                  = aws_s3_bucket.bronze.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
