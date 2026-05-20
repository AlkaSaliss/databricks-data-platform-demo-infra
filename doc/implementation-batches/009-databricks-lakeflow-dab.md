# Implementation Batch 009: Databricks Lakeflow DAB

## Goal

Add the Databricks side of the streaming demo so the S3 bronze files written by local Flink become a complete Unity Catalog bronze, silver, and gold flow.

## Scope

- Add `databricks-lakehouse-infra` for Unity Catalog catalog, schemas, storage credential, external location, and external volume.
- Add `databricks/energy_market` as a Databricks Asset Bundle.
- Use Lakeflow Spark Declarative Pipelines with Auto Loader.
- Read only the Flink raw bronze Parquet output as the Databricks source of truth.
- Produce daily gold KPIs rather than hourly rollups.

## Data Flow

```text
Flink raw Parquet files
  -> /Volumes/energy_market_demo/bronze/streaming_lake/bronze/raw_fr_energy_grid/
  -> energy_market_demo.bronze.raw_fr_energy_grid
  -> energy_market_demo.silver.fr_energy_market_snapshots_15min
  -> energy_market_demo.gold.fr_energy_market_kpis_daily
```

## Local Commands

```bash
make databricks-bundle-validate
make databricks-bundle-deploy
make databricks-bundle-run
```

These commands require a working Databricks CLI profile or equivalent Databricks environment variables.

## Acceptance Criteria

- The external volume can list the raw Flink bronze files.
- The bronze streaming table ingests new Parquet files with Auto Loader.
- The silver streaming table parses France Eco2mix payload fields and computes demo metrics.
- The gold materialized view groups silver snapshots into daily KPIs by `country_code` and `event_date`.
