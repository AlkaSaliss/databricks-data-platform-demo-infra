# Streaming Lake Infrastructure

This stack creates the S3 bucket used by local Flink jobs to land streaming lake outputs.

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

The raw France energy-grid bronze output is written under:

```text
s3://<bronze-bucket>/bronze/raw_fr_energy_grid/
```

After `workspace-infra` is deployed, Databricks reads the same raw bronze prefix through the Unity Catalog external volume:

```text
/Volumes/energy_market_demo/bronze/streaming_lake/bronze/raw_fr_energy_grid/
```

The current local Flink job also derives sibling demo outputs in the same bucket:

```text
s3://<bronze-bucket>/silver/fr_energy_market_snapshots_15min/
s3://<bronze-bucket>/gold/fr_energy_market_kpis_hourly/
```
