# Managed Flink Infra

The `managed-flink-infra` stack deploys the Amazon Managed Service for Apache Flink version of the raw France energy-grid bronze sink.

The stack is intentionally stopped by default. A minimal running Managed Flink application in `eu-west-1` bills for roughly two KPUs, so demo runs should start the application only for the validation window and stop it afterwards.

## Resources

- Versioned S3 artifact bucket for the PyFlink application archive
- CloudWatch log group and log stream with short retention
- IAM execution role for artifact reads, bronze S3 writes, and CloudWatch logging
- Amazon Managed Service for Apache Flink application using `FLINK-1_19`

## Dependencies

Deploy these stacks first:

```bash
make deploy STACK=confluent-kafka-infra
make deploy STACK=streaming-lake-infra
```

`managed-flink-infra` reads Kafka connection outputs from `confluent-kafka-infra` and the bronze S3 URI from `streaming-lake-infra`.

## Package

Build the application archive before planning or deploying the stack:

```bash
make managed-flink-package
```

The package is written to:

```text
build/managed-flink/raw_fr_energy_grid_to_s3.zip
```

The package contains the PyFlink job and a single dependency jar for the Kafka SQL connector and Parquet sink dependencies.

## Deploy

```bash
make plan STACK=managed-flink-infra
make deploy STACK=managed-flink-infra
```

The live stack sets `start_application = false`, so deployment creates the application without starting KPU billing for a running job.

## Operate

Start the application for a demo:

```bash
make managed-flink-start
```

Check status:

```bash
make managed-flink-status
```

Stop the application after validation:

```bash
make managed-flink-stop
```

CloudWatch logs are written to the log group exposed by the `cloudwatch_log_group_name` Terraform output.

## Acceptance Check

1. Start the Managed Flink application.
2. Publish source events with `make kafka-producer-docker-run LAST_DAYS=1`.
3. Confirm the application reaches `RUNNING`.
4. Confirm Parquet files appear under the existing `raw_fr_energy_grid_bronze_uri`.
5. Stop the application.
