# 002 - Local France Kafka Producer

## Goal

Prove that the Confluent Kafka infrastructure from batch 001 can be used from a developer machine by fetching real France Eco2mix national data from Opendatasoft and publishing raw energy-grid events to `raw.fr.energy_grid`.

## Resources

- Python producer app under `apps/producers/energy_market`
- Reusable Kafka wrapper for Confluent Cloud authentication
- France Eco2mix API client and raw-event mapper using the raw Kafka envelope
- Offline sample event generator for CI and local smoke tests
- Makefile targets for dry-run and publish flows
- Unit tests for event shape and missing Kafka configuration

## Local Setup

Install the Python package with test dependencies:

```bash
python3 -m pip install -e "./apps/producers/energy_market[test]"
```

Before publishing to Kafka, source the local configuration and retrieve producer credentials from Terraform outputs:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
. ./bin/set_kafka_output_api_keys.sh
```

The helper exports:

- `KAFKA_BOOTSTRAP_SERVERS`
- `KAFKA_TOPIC`
- `KAFKA_API_KEY`
- `KAFKA_API_SECRET`

## Commands

Validate offline sample event generation without Kafka:

```bash
make kafka-produce-sample-dry-run
```

Validate real Eco2mix API retrieval without publishing:

```bash
make kafka-produce-real-dry-run
```

Publish three real Eco2mix events:

```bash
make kafka-produce-sample
```

Publish a custom number of real Eco2mix events:

```bash
make kafka-produce-sample COUNT=10
```

Run producer tests:

```bash
make producer-test
```

## Expected Behavior

Offline dry-run prints sample raw event-envelope JSON to stdout and does not contact Kafka or the Eco2mix API. Real dry-run fetches recent records with actual consumption values from `https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets/eco2mix-national-tr/records` and prints mapped raw envelopes. Each envelope includes curated convenience fields and the full Opendatasoft record under `payload.source_fields`. Publish mode fetches recent real records and sends them to the topic stored in `KAFKA_TOPIC`, which should be `raw.fr.energy_grid` for the current infrastructure.

## Troubleshooting

- Missing Kafka environment variables: source `bin/set_kafka_output_api_keys.sh` after `set_env_vars.sh` and `set_aws_credentials.sh`.
- Terraform output failures: confirm batch 001 has been applied and AWS credentials can read the shared Terraform state backend.
- Kafka publish failures: confirm the Confluent stack exists, the producer API key has not been rotated, and the Confluent account has billing enabled.
- Eco2mix API failures: retry later or reduce `COUNT`; the source dataset is refreshed periodically and may enforce API quotas.
