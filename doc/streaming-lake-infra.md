# Streaming Lake Infrastructure

This stack creates the S3 bucket used by local Flink jobs to land bronze streaming output.

## Resources

- S3 bucket: `${prefix}-streaming-bronze`
- AES256 server-side encryption
- Public access block
- Standard Terragrunt/AWS provider tags

## Outputs

- `bronze_bucket_name`
- `bronze_bucket_arn`
- `raw_fr_energy_grid_bronze_uri`

## Usage

```bash
make plan STACK=streaming-lake-infra
make deploy STACK=streaming-lake-infra
```

The initial Flink batch writes raw France energy-grid bronze Parquet files under:

```text
s3://<bronze-bucket>/bronze/raw_fr_energy_grid/
```
