# 003 - Dockerized Energy Market Producer

## Goal

Package the France Eco2mix producer as a Docker Compose app and support publishing all measured records from the last N days.

## Resources

- Dockerfile and Compose file under `apps/producers/energy_market`
- Compose service: `france-eco2mix-producer`
- Producer CLI option: `--last-days`
- Root Make targets for Docker build, dry-run, real dry-run, and publish flows

## Local Setup

Build the producer image:

```bash
make kafka-producer-docker-build
```

Before publishing to Kafka, source the local configuration and retrieve producer credentials from Terraform outputs:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
. ./bin/set_kafka_output_api_keys.sh
```

Docker Compose reads these values from the caller environment:

- `KAFKA_BOOTSTRAP_SERVERS`
- `KAFKA_TOPIC`
- `KAFKA_API_KEY`
- `KAFKA_API_SECRET`

No Kafka secrets are written to Compose files.

## Commands

Run offline sample dry-run in Docker:

```bash
make kafka-producer-docker-dry-run
```

Fetch real Eco2mix data for the last day and print envelopes without publishing:

```bash
make kafka-producer-docker-real-dry-run LAST_DAYS=1
```

Publish the last two days of measured Eco2mix records:

```bash
make kafka-producer-docker-run LAST_DAYS=2
```

## Expected Behavior

`--last-days` fetches records where `consommation is not null`, `date_heure` is greater than or equal to `now - LAST_DAYS`, and `date_heure` is less than or equal to `now`. The producer paginates through all matching Opendatasoft records and maps each record into the raw Kafka envelope, preserving the complete source record under `payload.source_fields`.

## Troubleshooting

- Docker build failures: confirm Docker Desktop or another Docker engine is running.
- Empty last-days results: verify the Eco2mix API has measured records for the requested period.
- Kafka publish failures: confirm `bin/set_kafka_output_api_keys.sh` has exported the Kafka variables in the current shell.
