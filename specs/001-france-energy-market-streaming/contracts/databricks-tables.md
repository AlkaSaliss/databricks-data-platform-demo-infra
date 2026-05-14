# Databricks Table Contract

## Namespace

Catalog:

```text
energy_market_demo
```

Schemas:

```text
bronze
silver
gold
observability
```

## Tables

### energy_market_demo.bronze.raw_fr_energy_grid

Purpose: Preserve raw France source records and metadata.

Required columns:

```text
event_id string
source_system string
country_code string
source_event_time timestamp
ingestion_time timestamp
payload_json string
payload_hash string
_load_timestamp timestamp
_input_file_name string
```

### energy_market_demo.silver.energy_market_events

Purpose: Conformed France energy market event model.

Required columns:

```text
event_id string
country_code string
market_region string
event_time timestamp
metric_name string
metric_value double
unit string
energy_source string
source_system string
ingestion_time timestamp
processing_time timestamp
data_quality_status string
quality_error_code string
quality_error_message string
```

### energy_market_demo.gold.france_kpi_15min

Purpose: Dashboard-ready 15-minute France KPI mart.

Required columns:

```text
window_start timestamp
window_end timestamp
country_code string
market_region string
demand_mw double
total_generation_mw double
renewable_generation_mw double
renewable_share double
event_count bigint
late_event_count bigint
invalid_event_count bigint
processing_time timestamp
```

### energy_market_demo.observability.data_quality_observations

Purpose: Queryable invalid/warning event observations.

### energy_market_demo.observability.late_event_observations

Purpose: Queryable late-event observations.

### energy_market_demo.observability.pipeline_status

Purpose: Queryable freshness, latency, count, and current status output.

## Governance Rules

- Every table must have a table comment.
- Every table must include quality/layer metadata where supported.
- Owner assumption: data platform demo owner or configured Unity Catalog owner.
- Names must remain Unity Catalog-compatible.
