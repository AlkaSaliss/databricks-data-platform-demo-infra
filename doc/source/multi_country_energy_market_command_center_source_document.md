# Multi-Country Energy Market Command Center — Project Specification

## 1. Executive Summary

This project implements a demo data platform inspired by a global B2C energy organization operating across multiple geographies. The platform ingests open electricity-market data from France, Belgium, and Australia, streams it through Kafka, processes and normalizes it with Apache Flink, lands curated data into a Databricks Lakehouse, and exposes business-ready analytics through Databricks SQL dashboards.

The goal is to demonstrate an end-to-end architecture close to a real enterprise energy data platform:

```text
Open energy data sources
        |
        v
Python source connectors
        |
        v
Kafka topics
        |
        v
Apache Flink
- event-time processing
- country-specific normalization
- watermarks
- data quality checks
- windowed aggregations
        |
        v
S3
        |
        v
Databricks Lakehouse
- Bronze raw tables
- Silver conformed core model
- Gold analytics marts
- SQL dashboards
```

The demo is designed to show platform thinking rather than a simple data pipeline. It emphasizes multi-country harmonization, data contracts, streaming semantics, data quality, governance, observability, and business-facing energy analytics.

---

## 2. Business Context

Energy groups operating across several countries often face fragmented data landscapes. Each country may have different source systems, market operators, schemas, time zones, energy-mix definitions, and publication frequencies. A central data platform must ingest those heterogeneous data sources while exposing a common, reusable core model for analytics and decision-making.

This project simulates that challenge by harmonizing energy-market data from:

- France
- Belgium
- Australia

The platform enables cross-country analytics such as:

- electricity demand comparison
- renewable generation share
- carbon intensity monitoring
- energy-mix evolution
- market stress detection
- data freshness and quality monitoring

---

## 3. Target Audience

The project is intended for demonstration to:

- technical recruiters
- data platform managers
- lead data engineers
- cloud data architects
- Databricks / AWS stakeholders
- energy-domain data teams

The demo should communicate that the candidate understands not only Kafka, Flink, and Databricks, but also how to design a governed, scalable, multi-country data platform.

---

## 4. Project Objectives

### 4.1 Functional Objectives

The platform should:

1. Ingest open electricity-market data from multiple countries.
2. Publish raw events into Kafka topics.
3. Process streaming events with Apache Flink.
4. Normalize country-specific data into a common energy-market event model.
5. Apply data quality checks and data contract validation.
6. Compute near-real-time market KPIs.
7. Persist Bronze, Silver, and Gold layers in Databricks.
8. Expose dashboards for business and platform observability.

### 4.2 Technical Objectives

The demo should showcase:

- Kafka as the event backbone
- Flink as the real-time processing engine
- event-time processing and watermarks
- schema normalization
- multi-country core data modelling
- object storage as the landing layer
- Databricks Delta Lake for analytics
- Databricks SQL dashboards
- governance-oriented table organization
- pipeline observability
- data quality controls

### 4.3 Interview Objectives

The project should allow the presenter to explain:

- how to design a reusable data platform across geographies
- how to separate raw ingestion from conformed modelling
- how to handle country-specific schemas without polluting the core model
- how Flink handles event time, late events, and windowed metrics
- how Databricks supports lakehouse analytics and governance
- how to extend the architecture to B2C customer, contract, and billing data

---

## 5. Non-Goals

The first version of the project does not aim to:

- build a production-grade market data platform
- implement real-time trading features
- ingest private customer or billing data
- implement enterprise authentication end to end
- deploy all components on AWS Managed Services from day one
- implement full Collibra integration
- build advanced ML forecasting as the core deliverable

Optional extensions can address some of these areas later.

---

## 6. High-Level Use Case

The project answers the following question:

> How can an energy group build a reusable multi-country streaming data platform that harmonizes electricity-market data from several geographies into a common analytics-ready lakehouse model?

The demo should make this tangible with three concrete dashboard views:

1. **Global Energy Market Overview**
2. **Country Drill-Down**
3. **Data Platform Observability**

---

## 7. Source Data

### 7.1 France

Potential source: RTE / éCO2mix open data.

Useful metrics:

- national electricity consumption
- electricity production by source
- renewable generation
- imports / exports
- CO₂ intensity, where available
- timestamped quarter-hour or near-real-time records

### 7.2 Belgium

Potential source: Elia open data.

Useful metrics:

- Belgian electricity load
- generation by fuel type
- renewable generation
- balancing data
- CO₂ intensity
- market-region-level indicators

### 7.3 Australia

Potential sources: AEMO or OpenElectricity.

Useful metrics:

- regional demand
- generation by technology
- dispatch price, where available
- scheduled generation
- semi-scheduled generation
- interconnector flows
- renewable share

### 7.4 Source System Strategy

Each country source is implemented as an independent connector.

```text
france_source_connector.py
belgium_source_connector.py
australia_source_connector.py
```

Each connector performs minimal transformation only:

- fetch source data
- attach source metadata
- serialize records as JSON
- publish to Kafka raw topics

All serious normalization is handled downstream in Flink.

---

## 8. Architecture

### 8.1 Logical Architecture

```text
                 +-----------------------+
                 |   Open Data Sources   |
                 | RTE / Elia / AEMO     |
                 +-----------+-----------+
                             |
                             v
                 +-----------------------+
                 | Python Connectors     |
                 | API polling / replay  |
                 +-----------+-----------+
                             |
                             v
                 +-----------------------+
                 | Kafka                 |
                 | Raw country topics    |
                 +-----------+-----------+
                             |
                             v
                 +-----------------------+
                 | Apache Flink          |
                 | Normalize / validate  |
                 | window / aggregate    |
                 +-----------+-----------+
                             |
                             v
                 +-----------------------+
                 | S3 / MinIO            |
                 | Curated stream output |
                 +-----------+-----------+
                             |
                             v
                 +-----------------------+
                 | Databricks Lakehouse  |
                 | Bronze/Silver/Gold    |
                 +-----------+-----------+
                             |
                             v
                 +-----------------------+
                 | SQL Dashboards        |
                 | Business + platform   |
                 +-----------------------+
```

### 8.2 Local Demo Architecture

For fast implementation and portability:

```text
Docker Compose
├── Kafka
├── Kafka UI
├── Flink JobManager
├── Flink TaskManager
├── MinIO
├── Python source producers
└── Databricks notebooks / jobs
```

### 8.3 Cloud-Native Target Architecture

A production-like AWS version would map to:

```text
Source APIs
   |
   v
Kafka / Confluent Cloud / Amazon MSK
   |
   v
Amazon Managed Service for Apache Flink
   |
   v
Amazon S3
   |
   v
Databricks on AWS
   |
   v
Databricks SQL / Power BI
```

---

## 9. Kafka Design

### 9.1 Raw Topics

```text
raw.fr.energy_grid
raw.be.energy_grid
raw.au.energy_grid
```

Each raw topic preserves the original source-specific payload.

### 9.2 Normalized Topics

```text
normalized.energy_market_events
```

This topic contains events converted to the common core model.

### 9.3 Aggregated Topics

```text
gold.market_kpis_15min
gold.renewable_share_15min
gold.carbon_intensity_15min
```

These topics contain windowed metrics generated by Flink.

### 9.4 Alert Topics

```text
alerts.market_conditions
alerts.data_quality
alerts.late_events
```

These topics capture operational and business alerts.

### 9.5 Topic Naming Convention

Recommended convention:

```text
<layer>.<country_or_domain>.<entity_or_metric>
```

Examples:

```text
raw.fr.energy_grid
raw.be.energy_grid
normalized.energy_market_events
alerts.data_quality
```

---

## 10. Event Contract

### 10.1 Raw Event Envelope

All raw Kafka messages should use a lightweight envelope:

```json
{
  "event_id": "fr-rte-20260513T181500-consumption",
  "source_system": "rte_eco2mix",
  "country_code": "FR",
  "ingestion_time": "2026-05-13T18:15:10Z",
  "source_event_time": "2026-05-13T18:15:00Z",
  "payload": {
    "original_source_fields": "..."
  }
}
```

### 10.2 Normalized Event Model

Flink transforms raw events into the following core model:

```json
{
  "event_id": "fr-rte-20260513T181500-consumption",
  "country_code": "FR",
  "market_region": "FR_NATIONAL",
  "event_time": "2026-05-13T18:15:00Z",
  "metric_name": "electricity_consumption",
  "metric_value": 58320.0,
  "unit": "MW",
  "energy_source": null,
  "source_system": "rte_eco2mix",
  "ingestion_time": "2026-05-13T18:15:10Z",
  "processing_time": "2026-05-13T18:15:12Z",
  "data_quality_status": "valid"
}
```

### 10.3 Required Fields

The normalized event must include:

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
data_quality_status
```

### 10.4 Optional Fields

Optional fields include:

```text
energy_source
source_metric_name
source_unit
quality_error_code
quality_error_message
source_payload_hash
```

---

## 11. Core Data Model

### 11.1 Main Entity: Energy Market Event

The central Silver table is:

```text
silver_energy_market_events
```

It represents normalized time-series events from all countries.

### 11.2 Key Dimensions

```text
dim_country
dim_market_region
dim_energy_source
dim_metric
dim_source_system
```

### 11.3 Gold Facts

```text
fact_energy_market_kpi_15min
fact_renewable_share_15min
fact_carbon_intensity_15min
fact_market_stress_alert
fact_data_quality_observation
```

### 11.4 Country Dimension

```text
dim_country
- country_code
- country_name
- timezone
- market_operator
- currency
```

### 11.5 Market Region Dimension

```text
dim_market_region
- market_region_id
- country_code
- region_name
- region_type
```

### 11.6 Metric Dimension

```text
dim_metric
- metric_name
- metric_category
- standard_unit
- business_definition
```

Example metric names:

```text
electricity_consumption
total_generation
wind_generation
solar_generation
hydro_generation
gas_generation
coal_generation
nuclear_generation
renewable_generation
renewable_share
co2_intensity
market_price
import_export_balance
```

---

## 12. Flink Processing Design

### 12.1 Flink Jobs

The demo can be implemented with three Flink jobs.

#### Job 1 — Country Normalization

Input topics:

```text
raw.fr.energy_grid
raw.be.energy_grid
raw.au.energy_grid
```

Output topic:

```text
normalized.energy_market_events
```

Responsibilities:

- parse raw source payloads
- map source fields to common metric names
- standardize timestamps to UTC
- standardize units
- validate required fields
- emit invalid records to `alerts.data_quality`

#### Job 2 — Real-Time KPI Aggregation

Input topic:

```text
normalized.energy_market_events
```

Output topics:

```text
gold.market_kpis_15min
gold.renewable_share_15min
gold.carbon_intensity_15min
```

Responsibilities:

- assign event-time timestamps
- generate watermarks
- compute 15-minute country-level KPIs
- compute renewable share
- compute fossil share
- compute latest CO₂ intensity
- write aggregated results

#### Job 3 — Alert Detection

Input topic:

```text
normalized.energy_market_events
```

Output topic:

```text
alerts.market_conditions
```

Responsibilities:

- detect unusual demand spikes
- detect low renewable share periods
- detect high CO₂ intensity periods
- detect stale source data
- detect missing country feeds

---

## 13. Event-Time Processing

### 13.1 Timestamp Field

The canonical event-time field is:

```text
event_time
```

This should represent when the energy-market measurement actually happened, not when it was ingested or processed.

### 13.2 Watermark Strategy

Recommended demo configuration:

```text
max_out_of_orderness = 5 minutes
```

Conceptually:

```text
watermark = max_seen_event_time - 5 minutes
```

This allows the demo to show late and out-of-order events while keeping dashboards reasonably fresh.

### 13.3 Late Event Handling

Late events should be handled explicitly.

Recommended behavior:

```text
If event_time < current_watermark:
    send event to alerts.late_events
else:
    process normally
```

Optional advanced behavior:

```text
allow late updates for 10 minutes
recompute affected window
emit corrected aggregate
```

### 13.4 Demo Scenario

Inject the following sequence:

```text
10:00 event arrives
10:05 event arrives
10:03 event arrives late
```

Show that Flink places the 10:03 event into the correct 10:00-10:15 event-time window.

---

## 14. Data Quality Rules

### 14.1 Required Field Validation

Reject or flag events missing:

```text
event_id
event_time
country_code
metric_name
metric_value
unit
source_system
```

### 14.2 Value Validation

Examples:

```text
metric_value must not be null
production values must be >= 0
consumption values must be >= 0
renewable_share must be between 0 and 1
co2_intensity must be >= 0
country_code must be in accepted country list
unit must match expected metric unit
```

### 14.3 Freshness Validation

Track freshness by source:

```text
current_processing_time - max(event_time)
```

Alert if freshness exceeds threshold:

```text
FR feed stale > 30 minutes
BE feed stale > 30 minutes
AU feed stale > 30 minutes
```

### 14.4 Duplicate Detection

Use:

```text
event_id
```

or fallback hash:

```text
hash(source_system, country_code, metric_name, event_time, market_region)
```

### 14.5 Quality Output

Invalid records should be routed to:

```text
alerts.data_quality
```

Data quality observations should also be persisted in Databricks:

```text
gold_data_quality_observations
```

---

## 15. Databricks Lakehouse Design

### 15.1 Catalog and Schema Layout

Recommended structure:

```text
energy_market_demo
├── bronze
├── silver
├── gold
└── governance
```

### 15.2 Bronze Tables

```text
bronze.raw_fr_energy_grid
bronze.raw_be_energy_grid
bronze.raw_au_energy_grid
bronze.raw_flink_alerts
```

Bronze tables preserve raw source records.

Recommended columns:

```text
event_id
source_system
country_code
source_event_time
ingestion_time
payload_json
_load_timestamp
_input_file_name
```

### 15.3 Silver Tables

```text
silver.energy_market_events
silver.dim_country
silver.dim_market_region
silver.dim_metric
silver.dim_energy_source
silver.dim_source_system
```

Silver tables represent the conformed multi-country model.

### 15.4 Gold Tables

```text
gold.energy_market_kpis_15min
gold.country_comparison_daily
gold.renewable_share_15min
gold.carbon_intensity_15min
gold.market_stress_alerts
gold.data_quality_observations
gold.pipeline_observability
```

Gold tables are directly dashboard-ready.

### 15.5 Table Properties and Comments

Use comments to demonstrate governance maturity:

```sql
COMMENT ON TABLE silver.energy_market_events IS
'Conformed multi-country electricity market event model normalized from France, Belgium, and Australia open data sources.';
```

Example table properties:

```sql
ALTER TABLE silver.energy_market_events SET TBLPROPERTIES (
  'quality' = 'silver',
  'domain' = 'energy_market',
  'data_product' = 'multi_country_energy_market',
  'owner' = 'data_platform_team'
);
```

---

## 16. Analytics and KPIs

### 16.1 Business KPIs

```text
Total electricity consumption by country
Total generation by country
Renewable generation
Renewable share
Fossil generation share
CO₂ intensity
Import/export balance
Demand peak indicator
Market stress score
```

### 16.2 Platform KPIs

```text
Kafka consumer lag
Flink processing lag
watermark lag
late event count
invalid event count
source freshness delay
records processed per country
pipeline success/failure status
```

### 16.3 Derived Metrics

#### Renewable Share

```text
renewable_share = renewable_generation / total_generation
```

Renewable sources may include:

```text
wind
solar
hydro
bioenergy
```

#### Fossil Share

```text
fossil_share = fossil_generation / total_generation
```

Fossil sources may include:

```text
gas
coal
oil
```

#### Market Stress Score

Simple demo formula:

```text
market_stress_score =
    0.4 * normalized_demand
  + 0.3 * normalized_co2_intensity
  + 0.2 * low_renewable_penalty
  + 0.1 * stale_data_penalty
```

The exact formula can remain intentionally simple for a demo.

---

## 17. Dashboard Specification

### 17.1 Dashboard 1 — Global Energy Market Overview

Purpose:

> Provide a cross-country real-time view of electricity-market conditions.

Main widgets:

```text
Current electricity demand by country
Renewable share by country
CO₂ intensity by country
Energy mix by country
Market stress score
Latest data freshness by source
```

Visuals:

```text
KPI cards
line charts
stacked area charts
country comparison table
alert panel
```

### 17.2 Dashboard 2 — Country Drill-Down

Purpose:

> Allow a user to analyze one country in detail.

Filters:

```text
country_code
date range
metric_name
energy_source
```

Main widgets:

```text
energy demand over time
generation by source
renewable share trend
CO₂ intensity trend
market stress timeline
latest market alerts
```

### 17.3 Dashboard 3 — Data Platform Observability

Purpose:

> Show that the platform is reliable, monitored, and production-oriented.

Main widgets:

```text
records processed by source
late events by country
invalid events by rule
source freshness delay
watermark lag
pipeline latency
Kafka topic volumes
Flink job throughput
```

This dashboard is especially useful for interviews because it demonstrates DataOps and platform ownership.

---

## 18. Repository Structure

Recommended structure:

```text
energy-market-command-center/
├── README.md
├── docker-compose.yml
├── Makefile
├── pyproject.toml
├── configs/
│   ├── sources.yml
│   ├── kafka.yml
│   └── flink.yml
├── producers/
│   ├── common/
│   │   ├── kafka.py
│   │   └── http.py
│   ├── france_rte_producer.py
│   ├── belgium_elia_producer.py
│   └── australia_aemo_producer.py
├── flink_jobs/
│   ├── normalization_job.py
│   ├── kpi_aggregation_job.py
│   └── alert_detection_job.py
├── databricks/
│   ├── notebooks/
│   │   ├── 01_bronze_ingestion.py
│   │   ├── 02_silver_model.py
│   │   ├── 03_gold_marts.sql
│   │   └── 04_dashboard_queries.sql
│   ├── workflows/
│   │   └── energy_market_demo_job.yml
│   └── sql/
│       ├── ddl_bronze.sql
│       ├── ddl_silver.sql
│       └── ddl_gold.sql
├── tests/
│   ├── test_event_contracts.py
│   ├── test_normalization.py
│   └── test_quality_rules.py
└── docs/
    ├── architecture.md
    ├── data_model.md
    └── demo_script.md
```

---

## 19. Implementation Plan

### Phase 1 — Local Streaming Skeleton

Deliverables:

```text
Docker Compose with Kafka, Flink, MinIO
one Python producer
one Flink job reading Kafka and printing normalized events
```

Success criteria:

```text
raw events are visible in Kafka
Flink reads and normalizes events
normalized records are produced successfully
```

### Phase 2 — Multi-Country Ingestion

Deliverables:

```text
France producer
Belgium producer
Australia producer
raw Kafka topics
country-specific normalization logic
```

Success criteria:

```text
all countries publish to Kafka
Flink produces a single normalized stream
schema validation works
```

### Phase 3 — Flink KPIs and Alerts

Deliverables:

```text
event-time windows
watermark configuration
15-minute KPI aggregation
alert detection
late-event routing
```

Success criteria:

```text
windowed KPIs are generated
late events are detected
market alerts are emitted
```

### Phase 4 — Databricks Lakehouse

Deliverables:

```text
Bronze tables
Silver conformed model
Gold dashboard tables
Databricks SQL queries
```

Success criteria:

```text
Databricks can query all layers
gold tables are dashboard-ready
lineage from raw to gold is clear
```

### Phase 5 — Dashboards and Demo Script

Deliverables:

```text
Global overview dashboard
Country drill-down dashboard
Data platform observability dashboard
5-10 minute demo script
```

Success criteria:

```text
business story is clear
technical architecture is explainable
demo can be run reliably
```

---

## 20. DataOps and CI/CD

### 20.1 Local Commands

Recommended Makefile targets:

```text
make setup
make start
make stop
make produce-fr
make produce-be
make produce-au
make run-flink-normalization
make run-flink-kpis
make test
make lint
```

### 20.2 Tests

Minimum tests:

```text
event contract validation
country-specific mapping
unit normalization
timestamp parsing
quality rule validation
KPI calculation
```

### 20.3 CI Pipeline

Recommended checks:

```text
formatting
linting
unit tests
schema contract tests
notebook syntax validation
SQL validation
```

### 20.4 Deployment Extension

For a more advanced version:

```text
GitLab CI or GitHub Actions
Databricks Asset Bundles
Terraform for cloud resources
Flink application deployment automation
```

---

## 21. Governance Design

### 21.1 Layered Governance

```text
Bronze: raw, restricted, source-level access
Silver: conformed, quality-controlled, internal analytics
Gold: certified business data products
```

### 21.2 Unity Catalog Design

Recommended namespace:

```text
energy_market_demo.bronze
energy_market_demo.silver
energy_market_demo.gold
energy_market_demo.governance
```

### 21.3 Ownership

Example ownership model:

```text
Data product owner: Energy Market Analytics
Technical owner: Data Platform Team
Source owners: FR / BE / AU connector owners
Consumers: Analysts, data scientists, platform monitoring users
```

### 21.4 Data Product Definition

Main data product:

```text
multi_country_energy_market
```

Certified outputs:

```text
gold.energy_market_kpis_15min
gold.country_comparison_daily
gold.renewable_share_15min
gold.carbon_intensity_15min
```

---

## 22. Observability

### 22.1 Pipeline Metrics

Track:

```text
records ingested per source
records processed by Flink
records written to storage
invalid records
late records
processing latency
watermark lag
source freshness
```

### 22.2 Business Anomaly Metrics

Track:

```text
demand spikes
low renewable share periods
high CO₂ intensity periods
missing country feeds
unusual market stress score
```

### 22.3 Recommended Observability Tables

```text
gold.pipeline_observability
gold.data_quality_observations
gold.market_stress_alerts
```

---

## 23. Demo Script

### 23.1 Opening Pitch

> This demo simulates a multi-country energy data platform. It ingests electricity-market data from France, Belgium, and Australia, streams it through Kafka, processes it with Flink using event-time semantics, lands curated outputs into Databricks, and exposes both business KPIs and platform observability dashboards.

### 23.2 Architecture Walkthrough

Explain:

```text
1. each country has its own source connector
2. raw events are published to Kafka
3. Flink normalizes source-specific schemas into a common model
4. event-time windows are used for accurate time-series analytics
5. curated data lands in Databricks Bronze/Silver/Gold layers
6. dashboards expose business and operational insights
```

### 23.3 Business Dashboard Demo

Show:

```text
renewable share by country
CO₂ intensity by country
energy mix over time
market stress alerts
```

### 23.4 Technical Dashboard Demo

Show:

```text
data freshness
late events
invalid records
pipeline throughput
watermark lag
```

### 23.5 Senior-Level Closing Message

> The important part is not only the pipeline itself, but the platform pattern: raw country-specific ingestion, a conformed core model, governed lakehouse layers, streaming quality controls, and reusable dashboards. This pattern can then be extended to B2C customer, contract, billing, and consumption data.

---

## 24. Interview Talking Points

### 24.1 Kafka

> Kafka acts as the event backbone. It decouples country-specific producers from downstream processing and enables replayability.

### 24.2 Flink

> Flink handles the real-time stateful processing layer: event-time windows, watermarks, late-event handling, normalization, and near-real-time KPI computation.

### 24.3 Databricks

> Databricks provides the governed analytical lakehouse: Bronze for raw preservation, Silver for the conformed core model, and Gold for certified business data products and dashboards.

### 24.4 Core Model

> The key design choice is to isolate source-specific complexity in normalization jobs and expose a stable cross-country event model to downstream consumers.

### 24.5 Data Quality

> Data quality should be implemented as part of the streaming pipeline, not only after landing. Invalid events, late events, and stale feeds are first-class observability signals.

### 24.6 Extensibility

> Onboarding a new country should require only a new source connector and mapping adapter. The Silver and Gold model should remain stable.

---

## 25. Risks and Mitigations

### Risk 1 — Source APIs Are Inconsistent

Mitigation:

```text
use cached sample payloads for demo replay
abstract source connectors
keep raw payloads in Bronze
```

### Risk 2 — Too Much Scope

Mitigation:

```text
start with one country end to end
then add Belgium and Australia as incremental adapters
```

### Risk 3 — Flink Complexity

Mitigation:

```text
implement one normalization job first
add windowed aggregation second
keep alerting rules simple
```

### Risk 4 — Dashboard Data Not Fresh During Demo

Mitigation:

```text
prepare replay mode
seed Kafka with historical sample events
show both live and replayed scenarios
```

### Risk 5 — Databricks Connectivity

Mitigation:

```text
write Flink outputs as Parquet to S3/MinIO
load them from Databricks notebooks
avoid direct Flink-to-Delta complexity in MVP
```

---

## 26. MVP Definition

The MVP should include:

```text
1 country fully implemented end to end
3 Kafka topics
1 Flink normalization job
1 Flink aggregation job
Bronze/Silver/Gold Databricks tables
1 business dashboard
1 observability dashboard
```

Recommended MVP country:

```text
France using RTE / éCO2mix data
```

Then add Belgium and Australia once the platform pattern works.

---

## 27. Target Final Demo

The ideal final version should show:

```text
France, Belgium, and Australia data streams
country-specific raw topics
one normalized cross-country stream
15-minute energy KPIs
late-event handling
quality alerts
Databricks Bronze/Silver/Gold tables
cross-country dashboard
platform observability dashboard
```

---

## 28. Why This Project Has Interview Impact

This project has strong impact because it demonstrates:

- understanding of the energy sector
- ability to model multi-country data platforms
- Kafka and Flink interoperability
- event-time streaming semantics
- Databricks lakehouse design
- data quality and observability
- governance-oriented thinking
- business-facing analytics
- extensible platform architecture

It positions the candidate as a lead data/platform engineer capable of owning architecture, delivery, and data quality end to end.

---

## 29. Final Positioning Statement

> I built this demo to reflect the challenges of a global energy data platform: heterogeneous country-level sources, streaming ingestion, real-time processing, a reusable core data model, governed lakehouse layers, and business-ready dashboards. The same pattern can be extended from public energy-market data to internal B2C domains such as customers, contracts, consumption, billing, and customer operations.

