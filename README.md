# Databricks Data Platform Demo Infra

[![PR Infrastructure Checks](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/pr-infra.yml/badge.svg)](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/pr-infra.yml)
[![Deploy Databricks Demo Workspace Infrastructure](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/deploy-infra.yml/badge.svg)](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/deploy-infra.yml)
[![Confluent Kafka Infrastructure](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/confluent-kafka-infra.yml/badge.svg)](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/confluent-kafka-infra.yml)
[![Producer Tests](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/producer-tests.yml/badge.svg)](https://github.com/AlkaSaliss/databricks-data-platform-demo-infra/actions/workflows/producer-tests.yml)

This repository contains Terraform modules, Terragrunt live stacks, Dockerized producers, and local PyFlink jobs for a Databricks data platform demo on AWS.

## Stack Overview

The active AWS/Databricks deployment is split into six stacks under `src/live/<env>/<region>`:

1. `terraform-state-infra`
2. `account-admin`
3. `network-infra`
4. `uc-metastore-infra`
5. `workspace-infra`
6. `streaming-lake-infra`

Recommended deployment order is the same as the list above. Destroy order is the reverse.

## Repository Layout

```text
.
├── Makefile
├── bin/
│   ├── set_aws_credentials.sh
│   └── set_env_vars.sh
├── doc/
│   ├── account-admin.md
│   ├── network-infra.md
│   ├── streaming-lake-infra.md
│   ├── terraform-state-infra.md
│   ├── uc-metastore-infra.md
│   └── workspace-infra.md
└── src/
├── apps/
│   ├── flink/
│   └── producers/
└── src/
    ├── live/
    │   └── dev/
    │       ├── env.hcl
    │       └── eu-west-1/
    │           ├── account-admin/
    │           ├── network-infra/
    │           ├── terraform-state-infra/
    │           ├── uc-metastore-infra/
    │           ├── workspace-infra/
    │           └── region.hcl
    ├── modules/
    └── root.hcl
```

## Environment Variables

Before deploying, set the following environment variables in the current shell session:

- `AWS_PROFILE_NAME`
- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`
- `DATABRICKS_OWNER_EMAIL`
- `TF_STATE_BUCKET`
- `TF_STATE_DYNAMODB_TABLE`

You can source the local helper script if you use it:

```bash
. ./bin/set_env_vars.sh
```

`terraform-state-infra` requires `TF_STATE_BUCKET` and `TF_STATE_DYNAMODB_TABLE`.
The Databricks stacks require `DATABRICKS_ACCOUNT_ID`, `DATABRICKS_CLIENT_ID`, `DATABRICKS_CLIENT_SECRET`, and `DATABRICKS_OWNER_EMAIL`.

## Stack Inputs

Most shared settings are centralized in:

- `src/live/dev/env.hcl`
- `src/live/dev/eu-west-1/region.hcl`
- `src/root.hcl`

Per-stack values stay in each stack's `terraform.tfvars`.

## Makefile Usage

The `Makefile` is intentionally simple and centers on stack operations.

```bash
# Show help
make help

# Plan one stack
make plan STACK=network-infra

# Deploy one stack
make deploy STACK=workspace-infra

# Destroy one stack
make destroy STACK=workspace-infra

# Run the full deployment sequence for one environment/region
make deploy-all ENV=dev REGION=eu-west-1

# Run the active CI/CD deployment sequence, excluding terraform-state-infra
make deploy-active-all ENV=dev REGION=eu-west-1

# Destroy the active CI/CD stacks in reverse order, excluding terraform-state-infra
make destroy-active-all ENV=dev REGION=eu-west-1
```

## Independent Confluent Kafka Infra

The Confluent Kafka stack is deployed independently from the Databricks/AWS stack sequence. It is not included in `deploy-all`, `deploy-active-all`, CI active planning, or destroy-all targets.

Source local Confluent configuration before running the stack:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
```

Then run the Kafka stack directly:

```bash
make plan STACK=confluent-kafka-infra
make deploy STACK=confluent-kafka-infra
```

The Kafka stack creates one producer MVP topic, `raw.fr.energy_grid`, plus producer credentials and Flink consumer credentials for local streaming demos.

The Confluent Kafka GitHub workflow validates and plans this stack independently. Configure these GitHub secrets before using it:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `CONFLUENT_CLOUD_API_KEY`
- `CONFLUENT_CLOUD_API_SECRET`

Optional secret:

- `AWS_SESSION_TOKEN`

## Streaming Lake Infra

The `streaming-lake-infra` stack creates the dedicated S3 bucket used by local Flink jobs for bronze Parquet output.

```bash
make plan STACK=streaming-lake-infra
make deploy STACK=streaming-lake-infra
```

Its `raw_fr_energy_grid_bronze_uri` output is exported by `bin/set_flink_output_vars.sh` and used as `FLINK_S3_BRONZE_URI`.

## Docker Kafka Producer

Producer demo runs are Docker-only. The Python package remains the container entrypoint implementation and the unit-test target.

Build the producer image:

```bash
make kafka-producer-docker-build
```

Validate offline France sample event generation without contacting Kafka:

```bash
make kafka-producer-docker-dry-run
```

Validate real Eco2mix API retrieval without publishing:

```bash
make kafka-producer-docker-real-dry-run LAST_DAYS=1
```

Runtime hardening controls are available on the producer Make targets:

- `RETRY_MAX_ATTEMPTS`
- `RETRY_BACKOFF_SECONDS`
- `REQUEST_RATE_LIMIT_PER_SECOND`
- `PUBLISH_RATE_LIMIT_PER_SECOND`
- `SCHEDULE_INTERVAL_SECONDS`
- `MAX_RUNS`
- `LOG_LEVEL`
- `LOG_FORMAT`

To publish real Eco2mix events to `raw.fr.energy_grid`, first export Kafka connection settings from the Confluent Terraform outputs:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
. ./bin/set_kafka_output_api_keys.sh
make kafka-producer-docker-run LAST_DAYS=1
```

`bin/set_kafka_output_api_keys.sh` exports producer runtime variables as `ENERGY_MARKET_KAFKA_*` and unsets generic `KAFKA_*` variables so the Confluent Terraform provider does not mistake producer credentials for provider configuration.

Run the hardened producer on a fixed schedule without publishing:

```bash
make kafka-producer-docker-scheduled-dry-run LAST_DAYS=1 SCHEDULE_INTERVAL_SECONDS=10 MAX_RUNS=2 LOG_FORMAT=text
```

Run producer unit tests directly when changing producer internals:

```bash
python3 -m pip install -e "./apps/producers/energy_market[test]"
make producer-test
```

## Local PyFlink Energy Processing

After deploying `confluent-kafka-infra` and `streaming-lake-infra`, export Flink Kafka and S3 settings:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
. ./bin/set_flink_output_vars.sh
```

`make flink-export-vars-local` prints these commands for convenience, but it cannot source variables into your current shell.

Build the local Flink image and validate non-secret config:

```bash
make flink-docker-build
make flink-bronze-dry-run-config
```

Submit the local Flink job. The target name is kept for compatibility, but the job now writes bronze, enriched snapshot, and hourly KPI outputs:

```bash
make flink-bronze-submit
```

In another shell with producer variables exported, publish events:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
. ./bin/set_kafka_output_api_keys.sh
make kafka-producer-docker-run LAST_DAYS=1
```

The job writes raw France energy-grid bronze Parquet files under `FLINK_S3_BRONZE_URI`, partitioned by `country_code` and `event_date`. It also writes two demo-ready datasets in the same streaming lake bucket:

- enriched 15-minute snapshots under `silver/fr_energy_market_snapshots_15min`
- hourly trend KPIs under `gold/fr_energy_market_kpis_hourly`

The enriched snapshot output keeps the demo intentionally compact: demand, forecast, forecast error, total generation, renewable/fossil share, CO2 intensity, and simple quality status. The hourly output aggregates those snapshots with average demand, peak demand, renewable share, CO2 intensity, forecast error, record counts, invalid counts, and a simple market stress label.

The Kafka source starts from committed consumer-group offsets and falls back to the earliest offset only for a new group. This keeps local Docker restarts from replaying the whole topic after Flink has checkpointed and committed progress for `FLINK_KAFKA_GROUP_ID`; leave the job running for at least one checkpoint after consumption before stopping it.

Run Flink job unit tests directly when changing job internals:

```bash
python3 -m pip install -e "./apps/flink/energy_market[test]"
make flink-test
```

## GitHub Actions CI/CD

The repository uses these GitHub Actions workflows:

- `.github/workflows/pr-infra.yml` runs validation and planning for the active AWS/Databricks stacks on pull requests.
- `.github/workflows/deploy-infra.yml` runs manual deployment for an approved AWS/Databricks commit.
- `.github/workflows/confluent-kafka-infra.yml` runs independent Confluent Kafka validation, planning, and manual deployment.
- `.github/workflows/streaming-lake-infra.yml` runs independent S3 bronze bucket validation, planning, and manual deployment.
- `.github/workflows/producer-tests.yml` runs producer unit tests, Docker producer dry-runs, Docker image validation, and Flink job unit tests without publishing to Kafka.

The AWS/Databricks workflows target the active workspace stacks sequentially for `dev/eu-west-1`:

1. `account-admin`
2. `network-infra`
3. `uc-metastore-infra`
4. `workspace-infra`

`terraform-state-infra` is intentionally excluded from CI/CD because it bootstraps the remote state bucket and lock table and is deployed once manually.
Active workspace destroys run in reverse order: `workspace-infra`, `uc-metastore-infra`, `network-infra`, `account-admin`.

`streaming-lake-infra` is deployed by the separate Streaming Lake workflow because it only needs AWS credentials and should not depend on Databricks CI secrets.

### GitHub Variables And Secrets

Both workflows read configuration from the `dev` GitHub Environment.
Configure required reviewers on that environment if PR planning and manual applies should wait for approval.
The workflow uses AWS credentials configured in GitHub secrets.

Configure these GitHub secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DATABRICKS_ACCOUNT_ID`
- `DATABRICKS_CLIENT_ID`
- `DATABRICKS_CLIENT_SECRET`

Optional secret:

- `AWS_SESSION_TOKEN`

Configure these GitHub variables:

- `DATABRICKS_OWNER_EMAIL`
- `DATABRICKS_ACCOUNT_ADMINS_JSON`
- `DATABRICKS_USERS_JSON`
- `WORKSPACE_USERS_JSON`
- `USER_DISPLAY_NAMES_JSON`

Optional variables:

- `UNITY_ADMIN_GROUP`
- `UNITY_USERS_GROUP`
- `CREATE_AUTOMATION_SERVICE_PRINCIPAL`
- `AUTOMATION_SERVICE_PRINCIPAL_NAME`

JSON variables must be valid JSON values because the workflow writes `terraform.tfvars.json`. Compact single-line JSON is recommended for GitHub variables, for example:

```json
["admin@example.com"]
```

```json
{
  "user@example.com": "User Name"
}
```

`TF_STATE_BUCKET` and `TF_STATE_DYNAMODB_TABLE` are not required by the workflow because the state bootstrap stack is excluded.
Network, metastore, and workspace names are defined directly in the tracked Terragrunt stack definitions under `src/live/dev/eu-west-1`.
The workflows generate runtime `terraform.tfvars.json` files with `scripts/generate-ci-tfvars.sh`.

### Pull Request Checks

The PR workflow runs:

- `make fmt-check`
- `make hcl-validate-active-all ENV=dev REGION=eu-west-1`
- `make validate-active-all ENV=dev REGION=eu-west-1`
- `make plan-active-all ENV=dev REGION=eu-west-1`

Plan logs are uploaded as GitHub Actions artifacts.

### Manual Deployment

From GitHub, open **Actions** > **Deploy Databricks Demo Workspace Infrastructure** > **Run workflow** for the workspace stacks.

Use `action=plan` to run validation and planning only.
Use `action=apply` to run validation and planning first, then wait for the `dev` Environment approval before applying the active stacks sequentially.
Use `action=destroy` to run validation and planning first, then wait for the `dev` Environment approval before destroying the active stacks in reverse order.

For the S3 bronze bucket, open **Actions** > **Streaming Lake Infrastructure** > **Run workflow** and choose `plan`, `apply`, or `destroy`.

## Stack Documentation

- [account-admin](./doc/account-admin.md)
- [terraform-state-infra](./doc/terraform-state-infra.md)
- [network-infra](./doc/network-infra.md)
- [uc-metastore-infra](./doc/uc-metastore-infra.md)
- [workspace-infra](./doc/workspace-infra.md)
- [streaming-lake-infra](./doc/streaming-lake-infra.md)
