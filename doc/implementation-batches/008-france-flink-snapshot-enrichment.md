# 008 - France Flink Snapshot Enrichment

## Goal

Make the France Flink processing demo more representative than a raw read-and-dump while preserving the existing Kafka-to-S3 bronze sink contract.

The Eco2mix source is already published at a quarter-hour grain, so this batch treats each record as a 15-minute market snapshot. Flink enriches and validates those snapshots, then computes hourly trend KPIs from the enriched stream.

## Resources

- Existing PyFlink app under `apps/flink/energy_market`
- Existing Kafka input topic: `raw.fr.energy_grid`
- Existing raw bronze S3 output under `FLINK_S3_BRONZE_URI`
- New enriched snapshot output: `silver/fr_energy_market_snapshots_15min`
- New hourly KPI output: `gold/fr_energy_market_kpis_hourly`

## Processing

The job still writes raw bronze records unchanged. It also derives a compact France market snapshot from the Eco2mix payload:

- demand and forecast values
- total generation
- renewable and fossil shares
- forecast error
- CO2 intensity
- simple data quality status and error code

The hourly KPI output uses Flink event time with a five-minute watermark and one-hour tumbling windows. It includes average consumption, peak consumption, average renewable share, average CO2 intensity, average forecast error, snapshot counts, invalid snapshot counts, and a simple market stress label.

The Kafka source uses committed consumer-group offsets with an earliest-offset fallback for brand-new groups. This avoids replaying all historical topic messages on local Docker restarts once Flink has checkpointed and committed progress for the configured group.

## Commands

Run unit tests:

```bash
make flink-test
```

Build the local Flink image when Docker is available:

```bash
make flink-docker-build
```

Submit the same local Flink job as before. The target name is historical; the submitted job now writes all three outputs:

```bash
make flink-bronze-submit
```

## Expected Behavior

The existing bronze output remains backward compatible. A single Flink job now writes three datasets:

- raw bronze event envelopes
- enriched 15-minute France market snapshots
- hourly France market KPI rollups
