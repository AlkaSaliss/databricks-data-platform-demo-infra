# Data Model: France Energy Market Streaming Demo

## Raw France Energy Event

Represents one source-preserving France éCO2mix record published to
`raw.fr.energy_grid`.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| event_id | string | yes | Stable replay-safe identifier |
| source_system | string | yes | `rte_odre_eco2mix` |
| country_code | string | yes | `FR` |
| ingestion_time | timestamp | yes | Producer ingestion time in UTC |
| source_event_time | timestamp | yes | Measurement timestamp in UTC |
| payload | object | yes | Original source fields |
| payload_hash | string | no | Deterministic hash for duplicate fallback |

Validation:

- `country_code` must equal `FR`.
- `source_event_time` must parse as timestamp.
- `event_id` must be stable for identical source record replay.

## Normalized Energy Market Event

Conformed stream output used by Silver and KPI jobs.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| event_id | string | yes | Carries raw event ID or deterministic derived ID |
| country_code | string | yes | `FR` for MVP |
| market_region | string | yes | `FR_NATIONAL` for MVP |
| event_time | timestamp | yes | Event-time field for Flink |
| metric_name | string | yes | Canonical metric name |
| metric_value | decimal | yes | Numeric metric value |
| unit | string | yes | Standard unit, for example `MW` or ratio |
| energy_source | string | no | Required for generation-by-source metrics |
| source_system | string | yes | `rte_odre_eco2mix` |
| ingestion_time | timestamp | yes | Raw ingestion time |
| processing_time | timestamp | yes | Flink processing time |
| data_quality_status | string | yes | `valid`, `invalid`, or `warning` |
| quality_error_code | string | no | Populated for invalid/warning events |
| quality_error_message | string | no | Human-readable reason |

Validation:

- Required fields must be present.
- Demand and generation metrics must be non-negative.
- `event_time` must drive watermarking and windows.
- Deduplication uses `event_id`, with fallback hash of source, country, metric,
  event time, market region, and value.

## France KPI Aggregate

15-minute France business KPI output.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| window_start | timestamp | yes | Event-time window start |
| window_end | timestamp | yes | Event-time window end |
| country_code | string | yes | `FR` |
| market_region | string | yes | `FR_NATIONAL` |
| demand_mw | decimal | no | Latest or aggregated consumption |
| total_generation_mw | decimal | no | Aggregated generation |
| renewable_generation_mw | decimal | no | Wind, solar, hydro, bioenergy where available |
| renewable_share | decimal | no | Renewable generation / total generation |
| event_count | integer | yes | Count of valid normalized events |
| late_event_count | integer | yes | Late events observed for window |
| invalid_event_count | integer | yes | Invalid events observed for window |
| processing_time | timestamp | yes | Time aggregate was produced |

Validation:

- `renewable_share` must be between 0 and 1 when present.
- Window boundaries must align to 15-minute event-time windows.

## Data Quality Observation

Invalid or warning record emitted by validation.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| observation_id | string | yes | Stable observation identifier |
| event_id | string | no | Source event ID if available |
| country_code | string | yes | `FR` |
| source_system | string | yes | `rte_odre_eco2mix` |
| rule_id | string | yes | Validation rule identifier |
| severity | string | yes | `warning` or `error` |
| reason | string | yes | Human-readable reason |
| source_event_time | timestamp | no | Source event time if parseable |
| detected_at | timestamp | yes | Detection time |

## Late Event Observation

Records an event that arrived after the watermark boundary.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| observation_id | string | yes | Stable observation identifier |
| event_id | string | yes | Event ID |
| country_code | string | yes | `FR` |
| event_time | timestamp | yes | Measurement time |
| watermark_time | timestamp | yes | Watermark when detected |
| detected_at | timestamp | yes | Detection time |
| lateness_seconds | integer | yes | Detected lateness |
| handling_action | string | yes | `routed_to_observability` for MVP |

## Pipeline Status Observation

Operational health output used by observability dashboard.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| status_time | timestamp | yes | Observation time |
| country_code | string | yes | `FR` |
| source_system | string | yes | `rte_odre_eco2mix` |
| latest_event_time | timestamp | no | Latest valid event time |
| freshness_seconds | integer | no | Now minus latest event time |
| processed_count | integer | yes | Valid processed records |
| invalid_count | integer | yes | Invalid records |
| late_count | integer | yes | Late records |
| processing_latency_seconds | integer | no | End-to-end latency |
| pipeline_status | string | yes | `healthy`, `stale`, `degraded`, or `failed` |

## Lakehouse Tables

| Table | Source | Purpose |
|-------|--------|---------|
| energy_market_demo.bronze.raw_fr_energy_grid | raw S3 JSONL/Parquet | Preserve raw France source data |
| energy_market_demo.silver.energy_market_events | normalized S3/bronze | Conformed France events |
| energy_market_demo.gold.france_kpi_15min | aggregate S3/silver | Dashboard KPI mart |
| energy_market_demo.gold.france_business_dashboard | gold KPI table/view | Business dashboard query target |
| energy_market_demo.observability.data_quality_observations | observability S3 | Invalid/warning records |
| energy_market_demo.observability.late_event_observations | observability S3 | Late event records |
| energy_market_demo.observability.pipeline_status | observability S3 | Pipeline health |

## State Transitions

```text
raw event
  -> valid normalized event
  -> KPI aggregate
  -> Gold dashboard row

raw event
  -> invalid observation
  -> observability dashboard row

raw event
  -> late observation
  -> observability dashboard row
```
