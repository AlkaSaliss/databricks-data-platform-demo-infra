# Quickstart: France Energy Market Streaming Demo

This quickstart describes the intended MVP run sequence. It is a planning artifact;
implementation tasks will create the referenced commands and files.

## 1. Prerequisites

- Existing Databricks workspace and Unity Catalog metastore from this repository.
- Confluent Cloud cluster and API credentials.
- AWS credentials or profile with access to the raw/debug S3 prefix and the dedicated
  curated-events S3 bucket/prefix.
- Python 3.12 and uv.

## 2. Environment Variables

Export variables by name; do not commit values.

```bash
export CONFLUENT_BOOTSTRAP_SERVERS="..."
export CONFLUENT_API_KEY="..."
export CONFLUENT_API_SECRET="..."
export CONFLUENT_SECURITY_PROTOCOL="SASL_SSL"
export CONFLUENT_SASL_MECHANISM="PLAIN"
export AWS_PROFILE="..."
export AWS_REGION="eu-west-1"
export ENERGY_DEMO_RAW_S3_BUCKET="..."
export ENERGY_DEMO_RAW_S3_PREFIX="energy-market-command-center/raw"
export ENERGY_DEMO_CURATED_S3_BUCKET="..."
export ENERGY_DEMO_CURATED_S3_PREFIX="energy-market-command-center/curated"
export DATABRICKS_HOST="..."
export DATABRICKS_AUTH_TYPE="..."
```

## 3. Planned Local Workflow

```bash
cd apps/energy-market-command-center
make setup
make lint
make test
make validate-contracts
make produce-fr-sample
make run-flink-normalization
make run-flink-kpis
make demo-check
```

## 4. Expected Cloud Outputs

Confluent Cloud topic:

```text
raw.fr.energy_grid
```

S3 partitions:

```text
s3://<raw-or-debug-bucket>/<raw-prefix>/country_code=FR/dataset=raw_fr_energy_grid/event_date=YYYY-MM-DD/
s3://<dedicated-curated-bucket>/<curated-prefix>/country_code=FR/dataset=normalized_energy_market_events/event_date=YYYY-MM-DD/
s3://<dedicated-curated-bucket>/<curated-prefix>/country_code=FR/dataset=france_kpi_15min/event_date=YYYY-MM-DD/
s3://<dedicated-curated-bucket>/<curated-prefix>/country_code=FR/dataset=data_quality_observations/event_date=YYYY-MM-DD/
s3://<dedicated-curated-bucket>/<curated-prefix>/country_code=FR/dataset=late_event_observations/event_date=YYYY-MM-DD/
s3://<dedicated-curated-bucket>/<curated-prefix>/country_code=FR/dataset=pipeline_status_observations/event_date=YYYY-MM-DD/
```

Databricks namespace:

```text
energy_market_demo.bronze
energy_market_demo.silver
energy_market_demo.gold
energy_market_demo.observability
```

## 5. Databricks Validation

Planned assets:

```text
databricks/energy-market-command-center/notebooks/01_bronze_ingestion.py
databricks/energy-market-command-center/notebooks/02_silver_model.py
databricks/energy-market-command-center/notebooks/03_gold_marts.sql
databricks/energy-market-command-center/sql/dashboard_business_france.sql
databricks/energy-market-command-center/sql/dashboard_observability.sql
```

Run the Bronze/Silver/Gold assets, then execute:

- Business dashboard query: demand, generation, renewable generation, renewable share.
- Observability query: freshness, invalid count, late count, latency, status.

## 6. 10-Minute Demo Narrative

1. Business context: France electricity market data in an ENGIE-like platform.
2. Architecture: local producer, Confluent Cloud, Flink, S3, Databricks.
3. Streaming correctness: event time, watermark, deduplication, late events.
4. Lakehouse: Bronze raw, Silver conformed, Gold business-ready, observability.
5. Analytics: France KPI dashboard query.
6. Platform ownership: freshness, invalid records, late records, status.
7. Extensibility: Belgium and Australia as future source adapters.

## 7. Terraform Note

A dedicated curated-events bucket is required for normalized, analytics, and
observability outputs. If managed in this repository, it must be added as an isolated
demo storage resource and must not modify existing infrastructure modules. Raw/debug
storage may use a separate existing bucket or prefix.
