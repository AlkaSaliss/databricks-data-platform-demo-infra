# Feature Specification: France Energy Market Streaming Demo

**Feature Branch**: `001-france-energy-streaming-demo`  
**Created**: 2026-05-14  
**Status**: Draft  
**Input**: User description: "Create a France-first MVP of the Energy Market Command Center using public France RTE / ODRÉ éCO2mix electricity market data, local Python producers, Confluent Cloud Kafka, Apache Flink processing, AWS S3 curated outputs, Databricks Bronze/Silver/Gold tables, analytics SQL, and observability outputs. Do not implement code yet."

## Clarifications

### Session 2026-05-14

- Q: Which Kafka provider is in scope for the MVP? → A: Use Confluent Cloud only; local Kafka is excluded.
- Q: Where do producers run and how do they authenticate? → A: Producers run locally from the developer machine and authenticate to Confluent Cloud using environment variables.
- Q: Which object storage is in scope? → A: Use real AWS S3; reuse an existing bucket if infrastructure outputs expose one, otherwise specify an additive demo bucket/module as a future task.
- Q: How should Databricks ingest curated S3 outputs? → A: Use Databricks Auto Loader or batch reads from S3 depending on MVP complexity, preferring Auto Loader when an external location is already available.
- Q: What Unity Catalog namespace convention should be used? → A: Use catalog `energy_market_demo` with schemas `bronze`, `silver`, `gold`, and `observability`, compatible with the existing UC metastore.
- Q: What Flink runtime is acceptable for MVP? → A: Flink may run locally or as an application process for the MVP, but it must connect to Confluent Cloud and AWS S3; Amazon Managed Service for Apache Flink is a later hardening phase.
- Q: What is the first real France source? → A: Use RTE / ODRÉ éCO2mix as the first real open-data source.
- Q: Which file formats are acceptable for S3 outputs? → A: Use Parquet for analytics outputs; JSONL is acceptable for raw or debug outputs.
- Q: How must S3 outputs be partitioned? → A: Partition outputs by `country_code`, `dataset`, and `event_date`.
- Q: How are secrets represented? → A: Define required environment variables, but never store secret values in the repository.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Demonstrate France Energy Stream (Priority: P1)

A data platform engineer runs the France demo flow and shows that public France
electricity-market measurements can be captured, published, processed, stored, and
made available for analytics without using local Kafka or local object storage.

**Why this priority**: This is the MVP spine. It proves the end-to-end platform pattern
with one country before adding any multi-country complexity.

**Independent Test**: Use prepared France sample records to run the demo flow and verify
that raw, normalized, aggregated, and observability outputs are available for France.

**Acceptance Scenarios**:

1. **Given** valid France éCO2mix sample records and configured Confluent Cloud environment variables, **When** the local producer runs, **Then** raw France events are visible in Confluent Cloud.
2. **Given** raw France events with measurement timestamps, **When** stream processing runs, **Then** normalized France market events and basic KPI aggregates are produced using measurement time rather than arrival time.
3. **Given** processed France outputs in AWS S3, **When** the lakehouse ingestion step runs, **Then** Bronze, Silver, and Gold tables contain queryable France records.

---

### User Story 2 - Analyze France Market KPIs (Priority: P2)

An energy business analyst opens curated query outputs to understand France demand,
generation mix, renewable share, and market condition indicators for a selected period.

**Why this priority**: The demo must communicate business value, not only infrastructure
movement.

**Independent Test**: Run the provided business dashboard query against Gold outputs and
verify that it returns France KPI rows suitable for dashboard visualization.

**Acceptance Scenarios**:

1. **Given** curated France Gold data, **When** the analyst runs the business dashboard query, **Then** the result includes demand, generation, renewable share, and timestamped KPI fields.
2. **Given** a selected time range, **When** the analyst filters the query, **Then** only France records for that range are returned.

---

### User Story 3 - Monitor Demo Pipeline Health (Priority: P3)

A platform owner reviews observability outputs to explain freshness, invalid records,
late events, and pipeline status during the interview demo.

**Why this priority**: Observability demonstrates production-oriented platform thinking
and supports a credible technical narrative.

**Independent Test**: Run the observability dashboard query and verify that it returns
freshness, invalid event count, late event count, processing latency, and pipeline
status fields for France.

**Acceptance Scenarios**:

1. **Given** valid, invalid, and late sample records, **When** the processing flow runs, **Then** observability outputs distinguish accepted, invalid, and late records.
2. **Given** the latest processed France event, **When** the observability query runs, **Then** it reports source freshness and pipeline status for the demo.

---

### User Story 4 - Present the 10-Minute Interview Narrative (Priority: P4)

A technical recruiter or interviewer can follow the demo story from business context to
architecture, streaming correctness, lakehouse layers, analytics, observability, and
future country extensions.

**Why this priority**: The project is interview-oriented, so the artifacts must support
clear explanation as much as execution.

**Independent Test**: Walk through the quickstart and demo script in 10 minutes and
verify that each major talking point has a corresponding artifact or query output.

**Acceptance Scenarios**:

1. **Given** the completed MVP artifacts, **When** the presenter follows the demo script, **Then** the story covers business context, architecture, streaming, lakehouse, analytics, observability, and extensibility within 10 minutes.
2. **Given** questions about Belgium or Australia, **When** the presenter explains future scope, **Then** they can show those countries are documented extensions and not incomplete MVP behavior.

### Edge Cases

- France source data is unavailable during the demo: the feature must support prepared
  sample records so the demo can still run.
- A source record is missing required fields: the record must be routed to invalid
  event observability output rather than silently entering curated analytics.
- A record arrives after the configured watermark: the late-event handling behavior
  must be visible in observability output.
- Duplicate records are replayed: deduplication must produce deterministic outcomes.
- Cloud credentials are missing locally: setup validation must fail with a clear
  missing-configuration message and must not expose secret values.
- No reusable S3 bucket or external location is available from existing infrastructure:
  planning must define an additive demo storage task rather than modifying existing
  infrastructure modules.
- Curated files are present in storage but no new records arrived: lakehouse queries
  must still return the latest available state and freshness must indicate staleness.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The feature MUST define a France-only MVP flow using public RTE / ODRÉ éCO2mix electricity market data as the first real open-data source.
- **FR-002**: The feature MUST provide a way to publish valid France sample events to Confluent Cloud Kafka from a locally run producer.
- **FR-002a**: Local producers MUST authenticate to Confluent Cloud using environment variables and MUST NOT require committed credential files.
- **FR-003**: Raw France events MUST include a stable event identifier, source system, country code, source event time, ingestion time, and original payload.
- **FR-004**: Stream processing MUST consume raw France events and emit normalized energy market events with required fields for country, market region, event time, metric, value, unit, source, and quality status.
- **FR-005**: Stream processing MUST apply event-time semantics based on the source measurement timestamp.
- **FR-006**: Stream processing MUST define an explicit watermark policy and documented late-event behavior.
- **FR-007**: Stream processing MUST use deterministic deduplication based on event identity or a documented fallback key.
- **FR-008**: Stream processing MUST validate required fields, non-negative demand and generation values, accepted country codes, expected units, and timestamp parseability.
- **FR-009**: Invalid records MUST be exposed as first-class observability output with rule identifiers and human-readable reasons.
- **FR-010**: Late records MUST be exposed as first-class observability output with event time, detection time, and lateness information.
- **FR-011**: The feature MUST produce basic France KPI aggregates suitable for analytics, including demand, generation, renewable generation, renewable share, and record counts by time window.
- **FR-012**: Curated outputs MUST be written to real AWS S3 with partitions by `country_code`, `dataset`, and `event_date`.
- **FR-012a**: The feature MUST prefer reusing an existing S3 bucket or external location exposed by current infrastructure outputs; if unavailable, planning MUST define an additive demo bucket/module as a future task.
- **FR-012b**: Analytics outputs SHOULD use Parquet; raw and debug outputs MAY use JSONL.
- **FR-013**: Databricks ingestion MUST create or load Bronze, Silver, Gold, and observability tables for France using Unity Catalog-compatible names under catalog `energy_market_demo`.
- **FR-013a**: Databricks ingestion SHOULD use Auto Loader when an external location is already available; otherwise, batch reads from S3 are acceptable for MVP simplicity.
- **FR-014**: Bronze tables MUST preserve raw France payloads and source metadata.
- **FR-015**: Silver tables MUST expose conformed France energy market events with quality status and normalized metric names.
- **FR-016**: Gold tables MUST expose dashboard-ready France KPI outputs, and the observability schema MUST expose pipeline health outputs.
- **FR-017**: At least one business dashboard query MUST be available for France market KPIs.
- **FR-018**: At least one observability dashboard query MUST be available for freshness, invalid events, late events, processing latency, and pipeline status.
- **FR-019**: The feature MUST provide a quickstart and demo narrative that can be explained in 10 minutes.
- **FR-020**: The MVP MUST exclude local Kafka, MinIO, Belgium ingestion, Australia ingestion, private customer data, production-grade Flink CI/CD deployment, direct Flink-to-Delta sink, Power BI integration, and Collibra integration.
- **FR-021**: The feature MUST NOT require changes to existing Terraform/Terragrunt modules unless a later approved task explicitly adds isolated infrastructure.
- **FR-022**: The feature MUST document all required secret inputs by name and source mechanism without including secret values.
- **FR-023**: The MVP MAY run Flink locally or as an application process, but it MUST connect to Confluent Cloud and AWS S3; Amazon Managed Service for Apache Flink MUST be documented as a later hardening phase.

### Key Entities *(include if feature involves data)*

- **Raw France Energy Event**: Source-preserving event containing identity, source
  system, country code, source event time, ingestion time, and original France payload.
- **Normalized Energy Market Event**: Conformed event containing country, market
  region, event time, metric name, metric value, unit, source, processing metadata,
  and data quality status.
- **France KPI Aggregate**: Time-windowed business metric set containing demand,
  generation, renewable generation, renewable share, event count, and processing
  metadata.
- **Data Quality Observation**: Record describing invalid input or validation warnings,
  including rule identifier, reason, event identity when available, and source context.
- **Late Event Observation**: Record describing events that arrive after the accepted
  event-time boundary, including event time, detection time, and lateness duration.
- **Pipeline Status Observation**: Operational state containing source freshness,
  processed record counts, invalid record counts, late record counts, processing
  latency, and current status.
- **Lakehouse Table**: Queryable Bronze, Silver, or Gold dataset with Unity
  Catalog-compatible naming, owner assumption, table comments, and quality layer.
- **S3 Output Dataset**: File-based landing dataset partitioned by `country_code`,
  `dataset`, and `event_date`; analytics datasets prefer Parquet, while raw and debug
  datasets may use JSONL.

### Data Platform Constraints *(mandatory for Energy Market Command Center features)*

- **Scope**: This feature is the France MVP. Belgium and Australia are later
  extensions only.
- **Infrastructure Boundary**: Existing Terraform/Terragrunt modules and active live
  stacks are out of scope unless later planning creates explicit additive tasks.
- **Cloud Services**: The MVP path uses Confluent Cloud for Kafka and AWS S3 for
  object storage. Local Kafka and MinIO are not MVP dependencies.
- **Producer Location**: France producers run locally from the developer machine and
  connect to Confluent Cloud using environment variables.
- **Flink Runtime**: Flink may run locally or as an application process for the MVP,
  but must use Confluent Cloud and AWS S3. Managed Flink on AWS is a future hardening
  phase.
- **Storage**: Use real AWS S3. Prefer existing infrastructure outputs for bucket or
  external-location reuse; otherwise defer an additive demo bucket/module to planning.
- **Secrets**: Required environment variables include Confluent bootstrap server,
  Confluent API key, Confluent API secret, AWS profile or credential selectors, S3
  bucket or prefix settings, Databricks host, and Databricks authentication selector.
  Values must come from environment variables, local profiles, GitHub secrets,
  Databricks secrets, or secret managers.
- **Contracts**: The feature must specify raw Kafka event contracts, normalized Flink
  output contracts, aggregate output contracts, observability output contracts, S3
  object layout, and Databricks table schemas.
- **Streaming Semantics**: The feature must specify source event time, watermark
  policy, deduplication key, validation rules, and late-event handling.
- **Lakehouse Layers**: Bronze, Silver, Gold, and observability outputs must use the
  `energy_market_demo` catalog with `bronze`, `silver`, `gold`, and `observability`
  schemas, table comments, and owner assumptions.
- **Databricks Ingestion**: Prefer Auto Loader when an external location is available;
  batch reads from S3 are acceptable when simpler for the MVP.
- **Observability**: Freshness, invalid records, late events, processing latency, and
  pipeline status must be available as queryable outputs.
- **Demo Narrative**: The feature must support a 10-minute interview story covering
  business context, architecture, streaming correctness, lakehouse design, analytics,
  observability, and future country extension.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A presenter can complete the France MVP demo walkthrough in 10 minutes or less while covering all required narrative sections.
- **SC-002**: At least 20 representative France sample measurements can be processed from raw event publication through curated analytical output in one demo run.
- **SC-003**: The curated business output includes at least four France KPI fields: demand, generation, renewable generation, and renewable share.
- **SC-004**: The observability output includes freshness, invalid event count, late event count, processing latency, and pipeline status in a single queryable result.
- **SC-005**: Invalid sample records are identifiable by validation rule and reason with no manual log inspection required.
- **SC-006**: Late sample records are identifiable by event time and lateness information with no manual log inspection required.
- **SC-007**: Replaying duplicate sample records produces stable curated results for the same event identities.
- **SC-008**: A business analyst can run one provided query and obtain France market KPI rows suitable for dashboard visualization.
- **SC-009**: A platform owner can run one provided query and obtain France pipeline health rows suitable for dashboard visualization.
- **SC-010**: The specification and downstream artifacts clearly identify Belgium and Australia as future extensions, with no requirement to implement them in the MVP.

## Assumptions

- The repository's existing Databricks workspace and Unity Catalog metastore are
  already provisioned and available for use by the demo.
- France RTE / ODRÉ éCO2mix sample data may be cached for replay so the interview demo
  is not blocked by live source availability.
- The MVP prioritizes demonstrable data flow and explainability over production-grade
  operational automation.
- A single national France market region is sufficient for the MVP unless future
  planning introduces sub-regional detail.
- Direct Flink-to-Delta writes are intentionally excluded; curated files are landed in
  S3 and then loaded into Databricks.
- Dashboard creation means analytics-ready SQL queries for dashboard widgets, not a
  fully published BI workspace.
- AWS S3 output paths follow the convention `country_code`, `dataset`, and
  `event_date` as required partition fields.
- The planned Unity Catalog namespace is catalog `energy_market_demo` with schemas
  `bronze`, `silver`, `gold`, and `observability`.
