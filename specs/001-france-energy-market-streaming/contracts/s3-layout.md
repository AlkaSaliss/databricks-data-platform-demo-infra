# S3 Layout Contract

## Raw/Debug Output Path

```text
s3://<ENERGY_DEMO_RAW_S3_BUCKET>/<ENERGY_DEMO_RAW_S3_PREFIX>/country_code=FR/dataset=raw_fr_energy_grid/event_date=YYYY-MM-DD/
```

## Dedicated Curated-Events Bucket Path

```text
s3://<ENERGY_DEMO_CURATED_S3_BUCKET>/<ENERGY_DEMO_CURATED_S3_PREFIX>/country_code=FR/dataset=<dataset>/event_date=YYYY-MM-DD/
```

## Required Partitions

| Partition | Required | Example |
|-----------|----------|---------|
| country_code | yes | `FR` |
| dataset | yes | `france_kpi_15min` |
| event_date | yes | `2026-05-14` |

## Datasets

| Dataset | Format | Purpose |
|---------|--------|---------|
| raw_fr_energy_grid | JSONL or Parquet | Raw source-preserving records |
| normalized_energy_market_events | Parquet | Conformed valid events |
| france_kpi_15min | Parquet | Gold KPI aggregates |
| data_quality_observations | Parquet | Invalid/warning records |
| late_event_observations | Parquet | Late event records |
| pipeline_status_observations | Parquet | Pipeline health |

## Rules

- Raw/debug outputs may use JSONL.
- Curated normalized, analytics, and observability outputs must use the dedicated
  curated-events bucket.
- Analytics and observability outputs should use Parquet.
- Paths must not include secret values.
- The dedicated curated-events bucket must be added as an isolated demo storage
  resource and must not modify existing infrastructure modules.
