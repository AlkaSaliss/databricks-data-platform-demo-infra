# 005 - Local PyFlink S3 Bronze Sink

## Goal

Run a local Docker Compose Flink cluster that consumes the existing Confluent Kafka topic `raw.fr.energy_grid` and writes raw bronze Parquet files to a dedicated S3 bucket.

## Resources

- `streaming-lake-infra` Terraform/Terragrunt stack for the bronze S3 bucket
- Flink consumer service account, API key, and Kafka read/group ACLs in `confluent-kafka-infra`
- Sourced helper: `bin/set_flink_output_vars.sh`
- PyFlink app under `apps/flink/energy_market`
- Docker Compose services: `jobmanager`, `taskmanager`, and `job-submitter`

## Local Setup

Deploy the Kafka and streaming lake stacks:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
make deploy STACK=confluent-kafka-infra
make deploy STACK=streaming-lake-infra
```

Export producer and Flink runtime variables:

```bash
. ./bin/set_kafka_output_api_keys.sh
. ./bin/set_flink_output_vars.sh
```

`make flink-export-vars` only prints the source commands. Run the printed commands in the current shell before using `make flink-bronze-dry-run-config` or `make flink-bronze-submit`.

The Flink helper exports:

- `FLINK_KAFKA_BOOTSTRAP_SERVERS`
- `FLINK_KAFKA_TOPIC`
- `FLINK_KAFKA_API_KEY`
- `FLINK_KAFKA_API_SECRET`
- `FLINK_KAFKA_GROUP_ID`
- `FLINK_S3_BRONZE_URI`

## Commands

Build the local Flink image:

```bash
make flink-docker-build
```

Validate non-secret Flink config:

```bash
make flink-bronze-dry-run-config
```

Submit the bronze sink job:

```bash
make flink-bronze-submit
```

Publish source events with the Docker-only producer:

```bash
make kafka-producer-docker-run LAST_DAYS=1
```

Run unit tests:

```bash
python3 -m pip install -e "./apps/flink/energy_market[test]"
make flink-test
```

## Expected Behavior

The PyFlink job reads raw Kafka message values as JSON strings, extracts the raw envelope fields, preserves the complete payload and raw event JSON, and writes Parquet records partitioned by `country_code` and `event_date` under `FLINK_S3_BRONZE_URI`.

This batch intentionally lands raw bronze data only. Normalized events, KPI aggregation, alerts, and Databricks ingestion remain follow-up work.

## Troubleshooting

- Missing Flink environment variables: source `bin/set_flink_output_vars.sh` after deploying both required stacks.
- Kafka read failures: confirm `confluent-kafka-infra` has been redeployed so the Flink consumer API key and ACLs exist.
- S3 write failures: confirm AWS credentials are exported in the shell that runs Docker Compose and can write to the bronze bucket.
- Docker failures: confirm Docker Desktop or another Docker engine is running.
