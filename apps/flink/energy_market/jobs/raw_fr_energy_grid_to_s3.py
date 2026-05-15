"""Read raw France energy-grid Kafka events and write bronze Parquet to S3."""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping

DEFAULT_GROUP_ID = "energy-market-flink-bronze"


class FlinkConfigError(RuntimeError):
    """Raised when required Flink job configuration is missing."""


@dataclass(frozen=True)
class BronzeSinkConfig:
    kafka_bootstrap_servers: str
    kafka_topic: str
    kafka_api_key: str
    kafka_api_secret: str
    kafka_group_id: str
    s3_bronze_uri: str

    @classmethod
    def from_env(cls) -> "BronzeSinkConfig":
        required_vars = {
            "FLINK_KAFKA_BOOTSTRAP_SERVERS": os.getenv("FLINK_KAFKA_BOOTSTRAP_SERVERS"),
            "FLINK_KAFKA_TOPIC": os.getenv("FLINK_KAFKA_TOPIC"),
            "FLINK_KAFKA_API_KEY": os.getenv("FLINK_KAFKA_API_KEY"),
            "FLINK_KAFKA_API_SECRET": os.getenv("FLINK_KAFKA_API_SECRET"),
            "FLINK_S3_BRONZE_URI": os.getenv("FLINK_S3_BRONZE_URI"),
        }
        missing = [name for name, value in required_vars.items() if not value]
        if missing:
            missing_list = ", ".join(missing)
            raise FlinkConfigError(
                "Missing Flink environment variables: "
                f"{missing_list}. Source bin/set_flink_output_vars.sh first."
            )

        return cls(
            kafka_bootstrap_servers=normalize_bootstrap_servers(
                required_vars["FLINK_KAFKA_BOOTSTRAP_SERVERS"] or ""
            ),
            kafka_topic=required_vars["FLINK_KAFKA_TOPIC"] or "",
            kafka_api_key=required_vars["FLINK_KAFKA_API_KEY"] or "",
            kafka_api_secret=required_vars["FLINK_KAFKA_API_SECRET"] or "",
            kafka_group_id=os.getenv("FLINK_KAFKA_GROUP_ID", DEFAULT_GROUP_ID),
            s3_bronze_uri=required_vars["FLINK_S3_BRONZE_URI"] or "",
        )


def event_date_from_source_time(source_event_time: str) -> str:
    normalized = source_event_time.replace("Z", "+00:00")
    return datetime.fromisoformat(normalized).date().isoformat()


def normalize_bootstrap_servers(bootstrap_servers: str) -> str:
    if bootstrap_servers.startswith("SASL_SSL://"):
        return bootstrap_servers.removeprefix("SASL_SSL://")
    if bootstrap_servers.startswith("PLAINTEXT://"):
        return bootstrap_servers.removeprefix("PLAINTEXT://")
    return bootstrap_servers


def bronze_record_from_event(event: Mapping[str, Any]) -> dict[str, str]:
    source_event_time = _require_text(event, "source_event_time")
    return {
        "event_id": _require_text(event, "event_id"),
        "source_system": _require_text(event, "source_system"),
        "country_code": _require_text(event, "country_code"),
        "source_event_time": source_event_time,
        "ingestion_time": _require_text(event, "ingestion_time"),
        "payload_json": json.dumps(event.get("payload", {}), separators=(",", ":"), sort_keys=True),
        "raw_event_json": json.dumps(event, separators=(",", ":"), sort_keys=True),
        "event_date": event_date_from_source_time(source_event_time),
    }


def parse_bronze_field(raw_event_json: str, field_name: str) -> str:
    event = json.loads(raw_event_json)
    record = bronze_record_from_event(event)
    return record[field_name]


def kafka_source_ddl(config: BronzeSinkConfig) -> str:
    return f"""
CREATE TABLE raw_fr_energy_grid_kafka (
  raw_event_json STRING
) WITH (
  'connector' = 'kafka',
  'topic' = '{_sql(config.kafka_topic)}',
  'properties.bootstrap.servers' = '{_sql(config.kafka_bootstrap_servers)}',
  'properties.group.id' = '{_sql(config.kafka_group_id)}',
  'properties.security.protocol' = 'SASL_SSL',
  'properties.sasl.mechanism' = 'PLAIN',
  'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.plain.PlainLoginModule required username="{_sql(config.kafka_api_key)}" password="{_sql(config.kafka_api_secret)}";',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'raw'
)
""".strip()


def bronze_sink_ddl(config: BronzeSinkConfig) -> str:
    return f"""
CREATE TABLE raw_fr_energy_grid_bronze (
  event_id STRING,
  source_system STRING,
  country_code STRING,
  source_event_time STRING,
  ingestion_time STRING,
  payload_json STRING,
  raw_event_json STRING,
  event_date STRING
) PARTITIONED BY (country_code, event_date) WITH (
  'connector' = 'filesystem',
  'path' = '{_sql(config.s3_bronze_uri)}',
  'format' = 'parquet',
  'sink.partition-commit.delay' = '0s',
  'sink.partition-commit.policy.kind' = 'success-file'
)
""".strip()


def insert_sql() -> str:
    return """
INSERT INTO raw_fr_energy_grid_bronze
SELECT
  bronze_field(raw_event_json, 'event_id'),
  bronze_field(raw_event_json, 'source_system'),
  bronze_field(raw_event_json, 'country_code'),
  bronze_field(raw_event_json, 'source_event_time'),
  bronze_field(raw_event_json, 'ingestion_time'),
  bronze_field(raw_event_json, 'payload_json'),
  bronze_field(raw_event_json, 'raw_event_json'),
  bronze_field(raw_event_json, 'event_date')
FROM raw_fr_energy_grid_kafka
""".strip()


def run_job(config: BronzeSinkConfig) -> None:
    from pyflink.datastream import StreamExecutionEnvironment
    from pyflink.table import DataTypes, EnvironmentSettings, StreamTableEnvironment
    from pyflink.table.udf import udf

    env = StreamExecutionEnvironment.get_execution_environment()
    env.enable_checkpointing(30000)
    settings = EnvironmentSettings.in_streaming_mode()
    table_env = StreamTableEnvironment.create(env, environment_settings=settings)
    table_env.get_config().set("pipeline.name", "raw-fr-energy-grid-to-s3-bronze")

    table_env.create_temporary_function(
        "bronze_field",
        udf(parse_bronze_field, result_type=DataTypes.STRING()),
    )
    table_env.execute_sql(kafka_source_ddl(config))
    table_env.execute_sql(bronze_sink_ddl(config))
    table_env.execute_sql(insert_sql()).wait()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run-config", action="store_true", help="Validate and print non-secret job config.")
    args = parser.parse_args()

    config = BronzeSinkConfig.from_env()
    if args.dry_run_config:
        print(
            json.dumps(
                {
                    "kafka_bootstrap_servers": config.kafka_bootstrap_servers,
                    "kafka_topic": config.kafka_topic,
                    "kafka_group_id": config.kafka_group_id,
                    "s3_bronze_uri": config.s3_bronze_uri,
                },
                sort_keys=True,
            )
        )
        return 0

    run_job(config)
    return 0


def _require_text(event: Mapping[str, Any], field_name: str) -> str:
    value = event.get(field_name)
    if not isinstance(value, str) or not value:
        raise ValueError(f"Raw event is missing required field: {field_name}")
    return value


def _sql(value: str) -> str:
    return value.replace("'", "''")


if __name__ == "__main__":
    raise SystemExit(main())
