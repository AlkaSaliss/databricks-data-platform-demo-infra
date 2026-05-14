# Research: France Energy Market Streaming Demo

## Decision: Use Python 3.12 with uv

**Rationale**: Python 3.12 is the requested runtime and fits local producers,
contract validation, and PyFlink-compatible application code. uv gives reproducible
dependency management and fast local setup.

**Alternatives considered**: Poetry and pip-tools. Both are viable, but uv is the
requested tool and keeps setup simple.

## Decision: Use Confluent Cloud as the only Kafka provider

**Rationale**: The constitution and clarified spec require a cloud-backed MVP and
explicitly exclude local Kafka. Confluent Cloud demonstrates managed event backbone
behavior while local producer and Flink processes remain lightweight.

**Alternatives considered**: Local Kafka and Amazon MSK. Local Kafka violates the
MVP constraints. MSK is a possible future cloud alternative but not requested.

## Decision: Run producers locally with environment-variable authentication

**Rationale**: Local producers keep the demo easy to run from a developer machine
while still proving cloud connectivity. Environment variables avoid committed secrets.

**Alternatives considered**: Databricks jobs or containers for producers. Those add
deployment complexity before the France MVP is proven.

## Decision: Use RTE / ODRÉ éCO2mix as the first France source

**Rationale**: It provides public France electricity market measurements suitable for
consumption, production by source, and renewable share demo KPIs.

**Alternatives considered**: Other France public datasets. éCO2mix is the clearest
first source for energy-market storytelling.

## Decision: Allow PyFlink or Flink SQL for MVP stream processing

**Rationale**: Both can express event-time processing, watermarks, validation, and
windowed aggregation. The implementation should choose the simpler verified path once
dependencies are installed locally.

**Alternatives considered**: Spark Structured Streaming and direct Databricks
processing. Those would weaken the required Flink story for the interview demo.

## Decision: Land curated data in AWS S3 before Databricks

**Rationale**: S3 gives a durable cloud landing zone and avoids direct Flink-to-Delta
complexity. Databricks can then ingest with Auto Loader or batch reads.

**Alternatives considered**: Direct Flink-to-Delta sink. It is explicitly out of scope
for MVP and adds connector complexity.

## Decision: Prefer Parquet for analytics outputs and JSONL for raw/debug

**Rationale**: Parquet is efficient for Databricks analytics tables. JSONL keeps raw
event inspection and debug replay simple.

**Alternatives considered**: JSON everywhere is easier but less analytics-friendly;
Delta direct writes are out of scope.

## Decision: Partition S3 by country_code, dataset, and event_date

**Rationale**: The partition convention supports France MVP and future country
extension without changing layout semantics.

**Alternatives considered**: Layer-first paths. The required convention explicitly
names `country_code`, `dataset`, and `event_date`.

## Decision: Use energy_market_demo catalog with bronze/silver/gold/observability

**Rationale**: This aligns with Unity Catalog-compatible governance and keeps
observability separate from business Gold outputs.

**Alternatives considered**: Single schema or hive_metastore. Both weaken governance
story and table ownership clarity.

## Decision: No Terraform changes required for MVP

**Rationale**: Existing infrastructure already provisions a Databricks workspace and
UC metastore, with outputs for workspace and metastore buckets. The MVP can reuse an
available bucket or configure a manually provided S3 prefix.

**Alternatives considered**: Add a demo storage module now. That is optional
hardening and should be deferred unless planning or implementation proves reuse is
not possible.
