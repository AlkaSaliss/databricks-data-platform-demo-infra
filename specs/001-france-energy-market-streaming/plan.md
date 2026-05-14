# Implementation Plan: France Energy Market Streaming Demo

**Branch**: `001-france-energy-streaming-demo` | **Date**: 2026-05-14 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-france-energy-market-streaming/spec.md`

## Summary

Build a France-first Energy Market Command Center MVP that demonstrates an
end-to-end streaming data platform using public RTE / ODRÉ éCO2mix data. A local
Python producer publishes raw France events to Confluent Cloud Kafka. Flink jobs
normalize, validate, deduplicate, aggregate, and emit observability records with
event-time semantics. Curated outputs land in AWS S3 and are loaded into Databricks
Bronze, Silver, Gold, and observability schemas under Unity Catalog-compatible names.

The MVP is additive and isolated: application code goes under
`apps/energy-market-command-center`, Databricks assets under
`databricks/energy-market-command-center`, and Spec Kit artifacts under
`specs/001-france-energy-market-streaming`. Existing Terraform/Terragrunt modules
under `src/modules` and active stacks under `src/live` are not modified for the MVP.

## Technical Context

**Language/Version**: Python 3.12  
**Primary Dependencies**: uv, confluent-kafka, Apache Flink/PyFlink or Flink SQL,
boto3 or equivalent AWS SDK, Databricks SQL/notebooks, pytest, ruff  
**Storage**: Confluent Cloud Kafka for streaming; AWS S3 for landing; Databricks
managed Delta tables for Bronze/Silver/Gold analytics  
**Testing**: pytest for unit, contract, and integration tests; ruff for linting;
manual quickstart validation for cloud-backed demo flow  
**Target Platform**: Local developer machine for producer and MVP Flink process;
Confluent Cloud, AWS S3, and existing Databricks workspace on AWS  
**Project Type**: Data platform demo application plus Databricks lakehouse assets  
**Performance Goals**: Process at least 20 representative France measurements in one
demo run; support 15-minute KPI windows; complete 10-minute interview walkthrough  
**Constraints**: No local Kafka, no MinIO, no Belgium/Australia implementation in MVP,
no committed secrets, no direct Flink-to-Delta sink, no production-grade Flink CI/CD  
**Scale/Scope**: France only, national market region, sample/replay-friendly data
volume suitable for an interview demo

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Existing Infrastructure Preservation**: PASS. MVP changes are isolated under
  `apps/`, `databricks/`, and `specs/`. Existing `src/modules` and `src/live` are not
  modified. Any future demo bucket/module is optional hardening and must be additive.
- **Cloud-Backed MVP**: PASS. Kafka is Confluent Cloud and object storage is real AWS
  S3. Local Kafka and MinIO are excluded.
- **France-First Scope**: PASS. Only France RTE / ODRÉ éCO2mix is planned for MVP.
  Belgium and Australia are later extensions.
- **Spec-First Delivery**: PASS. This plan produces research, data model, contracts,
  quickstart, and later tasks before implementation starts.
- **Secrets Safety**: PASS. Secrets are environment variables, local profiles, GitHub
  secrets, Databricks secrets, or secret managers only. No values are committed.
- **Streaming Correctness**: PASS. Event time, watermarks, deterministic
  deduplication, validation, and late-event handling are explicitly planned.
- **Data Contract Discipline**: PASS. Kafka messages, Flink outputs, S3 layouts, and
  Databricks table schemas are defined in `contracts/` and `data-model.md`.
- **Lakehouse Discipline**: PASS. Databricks assets use Bronze/Silver/Gold plus
  observability schemas under catalog `energy_market_demo`.
- **Observability by Design**: PASS. Freshness, invalid events, late events,
  processing latency, and pipeline status are first-class outputs.
- **Interview Demo Readiness**: PASS. Quickstart and SQL assets support a 10-minute
  business and technical narrative.
- **MVP Simplicity**: PASS. Local process execution for producer and Flink is allowed
  while using cloud Kafka and S3. Managed Flink is deferred.
- **IaC Alignment**: PASS. No Terraform change is strictly required for MVP if an
  existing S3 bucket/external location is usable. If not, an additive demo storage
  module is a future task.

## Project Structure

### Documentation (this feature)

```text
specs/001-france-energy-market-streaming/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── raw-fr-energy-grid.schema.json
│   ├── normalized-energy-market-event.schema.json
│   ├── france-kpi-aggregate.schema.json
│   ├── observability-events.schema.json
│   ├── s3-layout.md
│   └── databricks-tables.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
apps/
└── energy-market-command-center/
    ├── README.md
    ├── Makefile
    ├── pyproject.toml
    ├── uv.lock
    ├── configs/
    │   ├── confluent.example.yml
    │   ├── france-rte-odre.example.yml
    │   ├── s3.example.yml
    │   └── databricks.example.yml
    ├── src/
    │   └── energy_market_command_center/
    │       ├── contracts/
    │       ├── producers/
    │       ├── flink_jobs/
    │       ├── observability/
    │       └── cli/
    ├── samples/
    │   └── france/
    └── tests/
        ├── contract/
        ├── integration/
        └── unit/

databricks/
└── energy-market-command-center/
    ├── notebooks/
    │   ├── 01_bronze_ingestion.py
    │   ├── 02_silver_model.py
    │   └── 03_gold_marts.sql
    ├── sql/
    │   ├── ddl_energy_market_demo.sql
    │   ├── dashboard_business_france.sql
    │   └── dashboard_observability.sql
    └── workflows/
        └── energy_market_command_center_job.yml
```

**Structure Decision**: Use a dedicated app directory for local producer/Flink/test
code and a separate Databricks asset directory for notebooks, SQL, and workflow
metadata. This isolates the demo from `src/live` and `src/modules`.

## 1. Proposed Repository Layout

Use the layout above. `apps/energy-market-command-center` owns local developer
workflow, source contracts, producer code, Flink job definitions, and tests.
`databricks/energy-market-command-center` owns notebook, SQL, and workflow assets.
Spec artifacts remain in `specs/001-france-energy-market-streaming`.

## 2. Environment Variables and Secret Handling

Required variables are documented by name only:

```text
CONFLUENT_BOOTSTRAP_SERVERS
CONFLUENT_API_KEY
CONFLUENT_API_SECRET
CONFLUENT_SECURITY_PROTOCOL
CONFLUENT_SASL_MECHANISM
AWS_PROFILE
AWS_REGION
ENERGY_DEMO_S3_BUCKET
ENERGY_DEMO_S3_PREFIX
DATABRICKS_HOST
DATABRICKS_AUTH_TYPE
DATABRICKS_TOKEN or DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET
```

Rules:

- No secret values in tracked files.
- Example config files use placeholders only.
- Local runs load secrets from environment variables or local cloud profiles.
- CI uses GitHub secrets if validation workflows are later added.
- Databricks jobs use Databricks secrets or service principal configuration.

## 3. Confluent Kafka Topic Design

MVP topic:

```text
raw.fr.energy_grid
```

Optional derived topics if Flink emits back to Kafka before S3:

```text
normalized.energy_market_events
gold.fr.market_kpis_15min
observability.fr.pipeline_events
```

Topic rules:

- Keys use deterministic event IDs where possible.
- Values follow JSON contracts in `contracts/`.
- Producer and Flink consumers use Confluent Cloud SASL_SSL settings from env vars.
- Topic creation can be manual for MVP; automated topic provisioning is a later
  hardening task.

## 4. France RTE / ODRÉ Source Connector Design

The MVP connector pulls or replays France RTE / ODRÉ éCO2mix records. It performs
minimal transformation:

- Fetch or read France electricity market records.
- Preserve original payload fields.
- Attach metadata: event ID, source system, `FR`, source event time, ingestion time.
- Publish to `raw.fr.energy_grid`.

The producer supports replay from checked-in non-sensitive sample payloads so demos do
not depend on live source availability.

## 5. Raw Event Contract

See `contracts/raw-fr-energy-grid.schema.json`.

Required fields:

```text
event_id
source_system
country_code
ingestion_time
source_event_time
payload
```

Rules:

- `country_code` is `FR`.
- `source_system` is `rte_odre_eco2mix`.
- `event_id` is stable for replay.
- `payload` preserves source fields needed for traceability.

## 6. Normalized Event Contract

See `contracts/normalized-energy-market-event.schema.json`.

Required fields:

```text
event_id
country_code
market_region
event_time
metric_name
metric_value
unit
source_system
ingestion_time
processing_time
data_quality_status
```

Rules:

- Event time is the France measurement timestamp.
- `market_region` defaults to `FR_NATIONAL`.
- Metric names use canonical values such as `electricity_consumption`,
  `total_generation`, `wind_generation`, `solar_generation`, `nuclear_generation`,
  `renewable_generation`, and `renewable_share`.

## 7. Flink Job Responsibilities

MVP can use PyFlink or Flink SQL. Runtime may be local or application process, but it
must connect to Confluent Cloud and AWS S3.

Jobs:

1. **Normalization and validation**
   - Read `raw.fr.energy_grid`.
   - Parse raw payloads.
   - Assign event time from `source_event_time`.
   - Apply watermark, initially 5 minutes max out-of-orderness.
   - Validate required fields, units, country code, and non-negative metric values.
   - Deduplicate by `event_id`, fallback hash if necessary.
   - Write normalized events and invalid/late observations.

2. **KPI aggregation**
   - Read normalized valid events.
   - Compute 15-minute France aggregates.
   - Produce demand, generation, renewable generation, renewable share, and counts.
   - Write Parquet analytics outputs to S3.

3. **Observability**
   - Track source freshness, invalid record count, late event count, processing
     latency, and pipeline status.
   - Write queryable observability outputs.

Amazon Managed Service for Apache Flink is a later hardening phase.

## 8. S3 Landing Path Conventions

Use real AWS S3. Required partition fields are `country_code`, `dataset`, and
`event_date`.

Base convention:

```text
s3://<bucket>/<prefix>/country_code=FR/dataset=<dataset>/event_date=YYYY-MM-DD/
```

Datasets:

```text
raw_fr_energy_grid
normalized_energy_market_events
france_kpi_15min
data_quality_observations
late_event_observations
pipeline_status_observations
```

Formats:

- Raw/debug: JSONL acceptable.
- Normalized/analytics/observability: Parquet preferred.

## 9. Databricks Catalog/Schema/Table Design

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

Tables:

```text
energy_market_demo.bronze.raw_fr_energy_grid
energy_market_demo.silver.energy_market_events
energy_market_demo.gold.france_kpi_15min
energy_market_demo.gold.france_business_dashboard
energy_market_demo.observability.data_quality_observations
energy_market_demo.observability.late_event_observations
energy_market_demo.observability.pipeline_status
```

Each table must include a comment, owner assumption, quality property, source system
metadata, and lineage to the S3 dataset.

## 10. Bronze Ingestion Strategy

Prefer Databricks Auto Loader if an external location is already configured for the S3
landing prefix. If not, use a batch read from S3 for MVP simplicity. Bronze preserves
raw France payloads, metadata, file path, and load timestamp.

## 11. Silver Transformation Strategy

Silver reads Bronze raw events and/or normalized Flink outputs, enforces canonical
schema, validates required fields, and exposes France market events with normalized
metric names and units. Silver is the conformed model that future Belgium and Australia
adapters must target without changing downstream Gold semantics.

## 12. Gold Mart Strategy

Gold marts are dashboard-ready:

- `gold.france_kpi_15min`: windowed France KPIs.
- `gold.france_business_dashboard`: business query/view for demand, generation,
  renewable share, and latest market state.

Gold must not depend on private customer data or external BI tools.

## 13. Observability Design

Observability is queryable through `energy_market_demo.observability`.

Outputs:

- Data freshness by source.
- Invalid events by rule.
- Late events by event date and lateness duration.
- Processing latency from source event time to processing/write time.
- Pipeline status with latest processed event time and current state.

The observability dashboard query must return a single result suitable for explaining
pipeline health during the demo.

## 14. Test Strategy

Use pytest and ruff. Test groups:

- Contract tests for all JSON schemas and required fields.
- Unit tests for France source mapping and metric normalization.
- Unit tests for deduplication key generation.
- Unit tests for validation rules.
- Unit tests for KPI formulas.
- Integration test with sample events through producer serialization and local
  processing boundaries.
- Optional cloud smoke test requiring explicit environment variables for Confluent
  Cloud and S3.
- Databricks SQL/notebook static checks where feasible.

Tests must not require committing credentials.

## 15. Local Runbook

Planned developer targets:

```text
make setup
make lint
make test
make validate-contracts
make produce-fr-sample
make run-flink-normalization
make run-flink-kpis
make upload-s3-smoke
make databricks-sql-check
make demo-check
```

Runbook sequence:

1. Export required environment variables.
2. Validate configuration without printing secret values.
3. Publish France sample events to Confluent Cloud.
4. Run Flink normalization and KPI jobs locally/application process.
5. Verify S3 partitions exist.
6. Run Databricks Bronze/Silver/Gold assets.
7. Run business and observability dashboard queries.
8. Walk the 10-minute demo script.

## 16. GitHub Actions Impact

No changes to existing infrastructure workflows are required for MVP. Existing
`.github/workflows/pr-infra.yml` and `deploy-infra.yml` should continue to focus on
Terraform/Terragrunt infrastructure.

Optional future workflow:

- App-only lint/test workflow for `apps/energy-market-command-center`.
- No cloud smoke tests by default unless required secrets are configured.
- Databricks asset validation can be a later non-deploying check.

## 17. Terraform/Terragrunt Impact

No Terraform/Terragrunt changes are strictly needed for the MVP if an existing S3
bucket or Unity Catalog external location can be reused from current infrastructure
outputs. Current relevant outputs include:

- `workspace-infra.root_bucket`
- `workspace-infra.databricks_host`
- `uc-metastore-infra.metastore_bucket`
- `uc-metastore-infra.metastore_id`
- `uc-metastore-infra.unity_catalog_iam_role_arn`

If no reusable bucket/external location is available, define an optional future
hardening task for an additive demo storage module or isolated Terragrunt stack. Do
not modify existing modules for MVP.

## 18. MVP Delivery Phases

1. **Contracts and samples**
   - Finalize schemas, sample France payloads, S3 layout, and table design.
2. **Producer**
   - Local France producer publishes sample/raw records to Confluent Cloud.
3. **Flink processing**
   - Normalize, validate, deduplicate, aggregate, and emit observability outputs.
4. **S3 landing**
   - Write raw/debug and curated datasets using partition convention.
5. **Databricks lakehouse**
   - Bronze, Silver, Gold, and observability assets load from S3.
6. **Demo readiness**
   - Business query, observability query, quickstart, and 10-minute narrative.

## 19. Later Extension to Belgium and Australia

Future country onboarding should add country-specific source producers and mapping
adapters while preserving the normalized event contract. New raw topics:

```text
raw.be.energy_grid
raw.au.energy_grid
```

Silver and Gold schemas should remain stable. Cross-country dashboards can be added
only after France is complete and tested.

## 20. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| France source unavailable during demo | Use checked-in non-sensitive sample payloads for replay |
| Confluent Cloud credentials misconfigured | Add config validation that names missing env vars without printing values |
| No reusable S3 external location | Use batch read with existing bucket if possible; otherwise defer additive storage IaC |
| Flink local runtime complexity | Keep MVP jobs narrow and allow Flink SQL or PyFlink based on simplest verified path |
| Late/out-of-order records unclear in demo | Include deliberate late sample events and observability query |
| Existing infra regression | Do not modify `src/modules` or active `src/live`; keep CI infra workflows unchanged |
| Scope creep to multi-country | Keep Belgium/Australia as documented extension only |

## Complexity Tracking

No constitution gate violations are planned. Optional future IaC for demo storage is
not part of MVP and must be justified in a later plan/task if needed.
