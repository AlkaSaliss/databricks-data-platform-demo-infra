# 006 - France Producer Historical Backfill

## Goal

Add an explicit historical backfill mode to the France Eco2mix producer so local demos can replay consolidated or definitive national records from a requested date range.

## Resources

- Producer CLI under `apps/producers/energy_market/producers/france_rte_producer.py`
- Historical ODRÉ dataset: `eco2mix-national-cons-def`
- Existing near-real-time ODRÉ dataset: `eco2mix-national-tr`
- Docker Make targets:
  - `make kafka-producer-docker-backfill-dry-run BACKFILL_START_DATE=2024-01-01 BACKFILL_END_DATE=2024-01-31`
  - `make kafka-producer-docker-backfill-run BACKFILL_START_DATE=2024-01-01 BACKFILL_END_DATE=2024-01-31`

## Expected Behavior

The backfill flags `--backfill-start-date` and `--backfill-end-date` must be provided together in `YYYY-MM-DD` format. The producer interprets those dates as UTC day boundaries, fetches records where `consommation is not null`, and includes both endpoints in the filter.

ODRÉ describes `eco2mix-national-cons-def` as consolidated and definitive historical national Eco2mix data. The existing `eco2mix-national-tr` dataset remains the source for latest-count and `--last-days` near-real-time producer runs.

Backfilled records use the same raw Kafka envelope and publish to the same `raw.fr.energy_grid` topic as the current France producer flow.

## Acceptance Criteria

- Backfill mode paginates through all matching historical records.
- Existing latest-count and `--last-days` modes continue to use `eco2mix-national-tr`.
- Dry-run backfills print mapped raw event envelopes without publishing.
- Publish backfills reuse the existing Kafka configuration, retry, logging, and rate-limit controls.
- `make producer-test` passes.
