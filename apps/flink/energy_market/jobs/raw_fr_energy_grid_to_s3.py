"""Read France Eco2mix events from Kafka and write demo lake outputs."""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass

DEFAULT_GROUP_ID = "energy-market-flink-bronze"
DEFAULT_STARTUP_MODE = "group-offsets"
STARTUP_MODES = {"group-offsets", "earliest-offset"}


class FlinkConfigError(RuntimeError):
    """Raised when required Flink job configuration is missing."""


@dataclass(frozen=True)
class BronzeSinkConfig:
    kafka_bootstrap_servers: str
    kafka_topic: str
    kafka_api_key: str
    kafka_api_secret: str
    kafka_group_id: str
    kafka_startup_mode: str
    s3_bronze_uri: str

    @classmethod
    def from_env(cls) -> "BronzeSinkConfig":
        values = {
            "FLINK_KAFKA_BOOTSTRAP_SERVERS": os.getenv("FLINK_KAFKA_BOOTSTRAP_SERVERS"),
            "FLINK_KAFKA_TOPIC": os.getenv("FLINK_KAFKA_TOPIC"),
            "FLINK_KAFKA_API_KEY": os.getenv("FLINK_KAFKA_API_KEY"),
            "FLINK_KAFKA_API_SECRET": os.getenv("FLINK_KAFKA_API_SECRET"),
            "FLINK_S3_BRONZE_URI": os.getenv("FLINK_S3_BRONZE_URI"),
        }
        missing = [name for name, value in values.items() if not value]
        if missing:
            raise FlinkConfigError(
                "Missing Flink environment variables: "
                f"{', '.join(missing)}. Source bin/set_flink_output_vars.sh first."
            )
        startup_mode = os.getenv("FLINK_KAFKA_STARTUP_MODE", DEFAULT_STARTUP_MODE)
        if startup_mode not in STARTUP_MODES:
            raise FlinkConfigError(
                "FLINK_KAFKA_STARTUP_MODE must be one of: "
                f"{', '.join(sorted(STARTUP_MODES))}."
            )

        return cls(
            kafka_bootstrap_servers=strip_kafka_protocol(values["FLINK_KAFKA_BOOTSTRAP_SERVERS"] or ""),
            kafka_topic=values["FLINK_KAFKA_TOPIC"] or "",
            kafka_api_key=values["FLINK_KAFKA_API_KEY"] or "",
            kafka_api_secret=values["FLINK_KAFKA_API_SECRET"] or "",
            kafka_group_id=os.getenv("FLINK_KAFKA_GROUP_ID", DEFAULT_GROUP_ID),
            kafka_startup_mode=startup_mode,
            s3_bronze_uri=values["FLINK_S3_BRONZE_URI"] or "",
        )

    @property
    def s3_snapshot_uri(self) -> str:
        return lake_uri(self.s3_bronze_uri, "silver/fr_energy_market_snapshots_15min")


def strip_kafka_protocol(bootstrap_servers: str) -> str:
    return (
        bootstrap_servers.removeprefix("SASL_SSL://")
        .removeprefix("PLAINTEXT://")
        .removeprefix("SSL://")
    )


def lake_uri(bronze_uri: str, suffix: str) -> str:
    normalized = bronze_uri.rstrip("/")
    prefix = "/bronze/"
    if normalized.startswith("s3://") and prefix in normalized:
        return f"{normalized.split(prefix, 1)[0]}/{suffix}/"
    return f"{normalized}/{suffix}/"


def kafka_source_ddl(config: BronzeSinkConfig) -> str:
    return f"""
CREATE TABLE raw_fr_energy_grid_kafka (
  raw_event_json STRING,
  event_time AS TO_TIMESTAMP(REPLACE(SUBSTRING(JSON_VALUE(raw_event_json, '$.source_event_time'), 1, 19), 'T', ' ')),
  WATERMARK FOR event_time AS event_time - INTERVAL '5' MINUTE
) WITH (
  'connector' = 'kafka',
  'topic' = '{sql(config.kafka_topic)}',
  'properties.bootstrap.servers' = '{sql(config.kafka_bootstrap_servers)}',
  'properties.group.id' = '{sql(config.kafka_group_id)}',
  'properties.security.protocol' = 'SASL_SSL',
  'properties.sasl.mechanism' = 'PLAIN',
  'properties.sasl.jaas.config' = 'org.apache.flink.kafka.shaded.org.apache.kafka.common.security.plain.PlainLoginModule required username="{sql(config.kafka_api_key)}" password="{sql(config.kafka_api_secret)}";',
  'properties.auto.offset.reset' = 'earliest',
  'scan.startup.mode' = '{sql(config.kafka_startup_mode)}',
  'format' = 'raw'
)
""".strip()


def bronze_sink_ddl(config: BronzeSinkConfig) -> str:
    return filesystem_sink(
        "raw_fr_energy_grid_bronze",
        """
  event_id STRING,
  source_system STRING,
  country_code STRING,
  source_event_time STRING,
  ingestion_time STRING,
  payload_json STRING,
  raw_event_json STRING,
  event_date STRING
""",
        config.s3_bronze_uri,
    )


def snapshot_sink_ddl(config: BronzeSinkConfig) -> str:
    return filesystem_sink(
        "fr_energy_market_snapshots_15min",
        """
  event_id STRING,
  country_code STRING,
  source_system STRING,
  market_region STRING,
  event_time TIMESTAMP(3),
  ingestion_time STRING,
  processing_time TIMESTAMP(3),
  consumption_mw DOUBLE,
  forecast_current_day_mw DOUBLE,
  forecast_error_mw DOUBLE,
  total_generation_mw DOUBLE,
  renewable_share DOUBLE,
  fossil_share DOUBLE,
  co2_intensity_g_per_kwh DOUBLE,
  data_quality_status STRING,
  quality_error_code STRING,
  event_date STRING
""",
        config.s3_snapshot_uri,
    )


def filesystem_sink(table_name: str, columns: str, path: str) -> str:
    return f"""
CREATE TABLE {table_name} (
{columns.rstrip()}
) PARTITIONED BY (country_code, event_date) WITH (
  'connector' = 'filesystem',
  'path' = '{sql(path)}',
  'format' = 'parquet',
  'sink.partition-commit.delay' = '0s',
  'sink.partition-commit.policy.kind' = 'success-file'
)
""".strip()


def bronze_insert_sql() -> str:
    return """
INSERT INTO raw_fr_energy_grid_bronze
SELECT
  JSON_VALUE(raw_event_json, '$.event_id'),
  JSON_VALUE(raw_event_json, '$.source_system'),
  JSON_VALUE(raw_event_json, '$.country_code'),
  JSON_VALUE(raw_event_json, '$.source_event_time'),
  JSON_VALUE(raw_event_json, '$.ingestion_time'),
  JSON_QUERY(raw_event_json, '$.payload'),
  raw_event_json,
  SUBSTRING(JSON_VALUE(raw_event_json, '$.source_event_time'), 1, 10)
FROM raw_fr_energy_grid_kafka
""".strip()


def snapshot_view_sql() -> str:
    return """
CREATE TEMPORARY VIEW fr_snapshots AS
SELECT
  *,
  wind_mw + solar_mw + hydro_mw + bioenergy_mw AS renewable_generation_mw,
  oil_mw + coal_mw + gas_mw AS fossil_generation_mw,
  oil_mw + coal_mw + gas_mw + nuclear_mw + wind_mw + solar_mw + hydro_mw + bioenergy_mw AS total_generation_mw
FROM (
  SELECT
    JSON_VALUE(raw_event_json, '$.event_id') AS event_id,
    JSON_VALUE(raw_event_json, '$.country_code') AS country_code,
    JSON_VALUE(raw_event_json, '$.source_system') AS source_system,
    COALESCE(JSON_VALUE(raw_event_json, '$.payload.market_region'), 'FR_NATIONAL') AS market_region,
    event_time,
    JSON_VALUE(raw_event_json, '$.ingestion_time') AS ingestion_time,
    CAST(JSON_VALUE(raw_event_json, '$.payload.metric_value') AS DOUBLE) AS consumption_mw,
    CAST(JSON_VALUE(raw_event_json, '$.payload.forecast_current_day_mw') AS DOUBLE) AS forecast_current_day_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.fioul') AS DOUBLE), 0) AS oil_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.charbon') AS DOUBLE), 0) AS coal_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.gaz') AS DOUBLE), 0) AS gas_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.nucleaire') AS DOUBLE), 0) AS nuclear_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.eolien') AS DOUBLE), 0) AS wind_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.solaire') AS DOUBLE), 0) AS solar_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.hydraulique') AS DOUBLE), 0) AS hydro_mw,
    COALESCE(CAST(JSON_VALUE(raw_event_json, '$.payload.generation_mw.bioenergies') AS DOUBLE), 0) AS bioenergy_mw,
    CAST(JSON_VALUE(raw_event_json, '$.payload.co2_intensity_g_per_kwh') AS DOUBLE) AS co2_intensity_g_per_kwh,
    SUBSTRING(JSON_VALUE(raw_event_json, '$.source_event_time'), 1, 10) AS event_date
  FROM raw_fr_energy_grid_kafka
)
""".strip()


def snapshot_insert_sql() -> str:
    return """
INSERT INTO fr_energy_market_snapshots_15min
SELECT
  event_id,
  country_code,
  source_system,
  market_region,
  event_time,
  ingestion_time,
  CURRENT_TIMESTAMP,
  consumption_mw,
  forecast_current_day_mw,
  consumption_mw - forecast_current_day_mw,
  total_generation_mw,
  renewable_generation_mw / NULLIF(total_generation_mw, 0),
  fossil_generation_mw / NULLIF(total_generation_mw, 0),
  co2_intensity_g_per_kwh,
  CASE
    WHEN consumption_mw IS NULL THEN 'invalid'
    WHEN LEAST(oil_mw, coal_mw, gas_mw, nuclear_mw, wind_mw, solar_mw, hydro_mw, bioenergy_mw) < 0 THEN 'invalid'
    WHEN consumption_mw > 0 AND ABS(consumption_mw - total_generation_mw) > consumption_mw * 0.2 THEN 'warning'
    ELSE 'valid'
  END,
  CASE
    WHEN consumption_mw IS NULL THEN 'missing_consumption'
    WHEN LEAST(oil_mw, coal_mw, gas_mw, nuclear_mw, wind_mw, solar_mw, hydro_mw, bioenergy_mw) < 0 THEN 'negative_generation'
    WHEN consumption_mw > 0 AND ABS(consumption_mw - total_generation_mw) > consumption_mw * 0.2 THEN 'generation_imbalance'
    ELSE CAST(NULL AS STRING)
  END,
  event_date
FROM fr_snapshots
""".strip()


def run_job(config: BronzeSinkConfig) -> None:
    from pyflink.datastream import StreamExecutionEnvironment
    from pyflink.table import EnvironmentSettings, StreamTableEnvironment

    env = StreamExecutionEnvironment.get_execution_environment()
    env.enable_checkpointing(10000)

    table_env = StreamTableEnvironment.create(env, environment_settings=EnvironmentSettings.in_streaming_mode())
    table_env.get_config().set("pipeline.name", "fr-energy-grid-demo")

    for ddl in [
        kafka_source_ddl(config),
        bronze_sink_ddl(config),
        snapshot_sink_ddl(config),
        snapshot_view_sql(),
    ]:
        table_env.execute_sql(ddl)

    statements = table_env.create_statement_set()
    statements.add_insert_sql(bronze_insert_sql())
    statements.add_insert_sql(snapshot_insert_sql())
    statements.execute().wait()


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
                    "kafka_startup_mode": config.kafka_startup_mode,
                    "s3_bronze_uri": config.s3_bronze_uri,
                    "s3_snapshot_uri": config.s3_snapshot_uri,
                },
                sort_keys=True,
            )
        )
        return 0

    run_job(config)
    return 0


def sql(value: str) -> str:
    return value.replace("'", "''")


if __name__ == "__main__":
    raise SystemExit(main())
