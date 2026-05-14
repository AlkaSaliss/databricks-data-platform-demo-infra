# 001 - Confluent Kafka Producer MVP

## Goal

Provision the first independently deployable Kafka infrastructure batch for the multi-country energy-market command center demo. This batch creates the Confluent Cloud resources needed for a local France producer to publish raw energy-grid events.

## Resources

- Confluent Cloud environment: `energy-market-demo-dev-confluent`
- Basic Kafka cluster: `energy-market-demo-dev-kafka`
- Cloud provider and region: `AWS/eu-west-1`
- Topic: `raw.fr.energy_grid`
- Local producer service account
- Kafka API key and secret for the local producer service account
- Kafka ACLs allowing the local producer to describe the cluster and write/describe the topic

Terraform also creates an internal cluster-admin service account and Kafka API key so it can manage the topic and ACLs. Those credentials are not local producer credentials.

## Local Setup

Source the existing local environment script before running Terragrunt:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
```

The scripts must export:

- `CONFLUENT_CLOUD_API_KEY`
- `CONFLUENT_CLOUD_API_SECRET`
- AWS credentials for the shared S3/DynamoDB Terraform backend

This Kafka stack is intentionally independent from the Databricks deployment sequence, but it uses the same shared `src/root.hcl` remote state convention as the other Terragrunt stacks.

## Commands

```bash
make fmt-check
make hcl-validate STACK=confluent-kafka-infra
make validate STACK=confluent-kafka-infra
make plan STACK=confluent-kafka-infra
```

## Expected Plan Result

The plan should show creation of:

- One Confluent environment
- One Basic Confluent Kafka cluster
- One Kafka topic named `raw.fr.energy_grid`
- One local producer service account
- One local producer Kafka API key
- Kafka ACLs for cluster describe, topic describe, and topic write

## Follow-Up Batches

- Add raw topics for Belgium and Australia.
- Add local producer configuration output or secret handling for client applications.
- Add Flink consumer/producer credentials and topics for normalized, KPI, and alert streams.
