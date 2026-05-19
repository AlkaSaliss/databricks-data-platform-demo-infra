# 007 - Amazon Managed Flink Bronze Sink

## Goal

Deploy the existing raw France energy-grid Kafka-to-S3 bronze sink on Amazon Managed Service for Apache Flink while reusing the local PyFlink processing logic.

## Resources

- `managed-flink-infra` Terraform/Terragrunt stack
- Managed Flink artifact S3 bucket
- Managed Flink execution IAM role and inline policy
- CloudWatch log group and stream
- Managed Flink application configured for `FLINK-1_19`
- PyFlink application archive at `build/managed-flink/raw_fr_energy_grid_to_s3.zip`

## Cost Control

The stack creates the Managed Flink application with `start_application = false`.

Start the app only for demo validation and stop it afterwards:

```bash
make managed-flink-start
make managed-flink-stop
```

This avoids leaving the minimal app running continuously, which would cost roughly `$179/month` in `eu-west-1`.

## Commands

Build the application archive:

```bash
make managed-flink-package
```

Deploy dependencies:

```bash
make deploy STACK=confluent-kafka-infra
make deploy STACK=streaming-lake-infra
```

Plan and deploy the Managed Flink stack:

```bash
make plan STACK=managed-flink-infra
make deploy STACK=managed-flink-infra
```

Start the managed app and check status:

```bash
make managed-flink-start
make managed-flink-status
```

Publish source events:

```bash
make kafka-producer-docker-run LAST_DAYS=1
```

Stop the managed app:

```bash
make managed-flink-stop
```

## Expected Behavior

The Managed Flink job reads the same Confluent Kafka topic as the local Flink job, extracts the same raw envelope fields, preserves the full payload and raw event JSON, and writes Parquet records to the existing bronze S3 prefix partitioned by `country_code` and `event_date`.

## Troubleshooting

- Missing application archive: run `make managed-flink-package` before `plan` or `deploy`.
- Kafka authentication failures: confirm `confluent-kafka-infra` has current Flink consumer API key outputs and ACLs.
- S3 write failures: confirm the execution role policy includes the deployed bronze bucket and prefix.
- No new S3 files: confirm the app is `RUNNING`, producer events were published after startup, and CloudWatch logs do not show connector errors.
