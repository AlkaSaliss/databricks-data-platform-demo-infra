from __future__ import annotations

import json

import pytest

from jobs.raw_fr_energy_grid_to_s3 import (
    BronzeSinkConfig,
    FlinkConfigError,
    bronze_record_from_event,
    bronze_sink_ddl,
    event_date_from_source_time,
    insert_sql,
    kafka_source_ddl,
    normalize_bootstrap_servers,
    parse_bronze_field,
)


def test_config_fails_when_required_env_vars_are_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in [
        "FLINK_KAFKA_BOOTSTRAP_SERVERS",
        "FLINK_KAFKA_TOPIC",
        "FLINK_KAFKA_API_KEY",
        "FLINK_KAFKA_API_SECRET",
        "FLINK_KAFKA_GROUP_ID",
        "FLINK_S3_BRONZE_URI",
    ]:
        monkeypatch.delenv(name, raising=False)

    with pytest.raises(FlinkConfigError, match="Missing Flink environment variables"):
        BronzeSinkConfig.from_env()


def test_config_reads_env_vars(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FLINK_KAFKA_BOOTSTRAP_SERVERS", "pkc.example.aws.confluent.cloud:9092")
    monkeypatch.setenv("FLINK_KAFKA_TOPIC", "raw.fr.energy_grid")
    monkeypatch.setenv("FLINK_KAFKA_API_KEY", "key")
    monkeypatch.setenv("FLINK_KAFKA_API_SECRET", "secret")
    monkeypatch.setenv("FLINK_KAFKA_GROUP_ID", "energy-market-flink-bronze")
    monkeypatch.setenv("FLINK_S3_BRONZE_URI", "s3://bucket/bronze/raw_fr_energy_grid/")

    config = BronzeSinkConfig.from_env()

    assert config.kafka_topic == "raw.fr.energy_grid"
    assert config.kafka_bootstrap_servers == "pkc.example.aws.confluent.cloud:9092"
    assert config.kafka_group_id == "energy-market-flink-bronze"
    assert config.s3_bronze_uri == "s3://bucket/bronze/raw_fr_energy_grid/"


def test_config_strips_confluent_bootstrap_protocol(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FLINK_KAFKA_BOOTSTRAP_SERVERS", "SASL_SSL://pkc.example:9092")
    monkeypatch.setenv("FLINK_KAFKA_TOPIC", "raw.fr.energy_grid")
    monkeypatch.setenv("FLINK_KAFKA_API_KEY", "key")
    monkeypatch.setenv("FLINK_KAFKA_API_SECRET", "secret")
    monkeypatch.setenv("FLINK_S3_BRONZE_URI", "s3://bucket/bronze/raw_fr_energy_grid/")

    assert BronzeSinkConfig.from_env().kafka_bootstrap_servers == "pkc.example:9092"
    assert normalize_bootstrap_servers("PLAINTEXT://localhost:9092") == "localhost:9092"


def test_bronze_record_preserves_raw_envelope_and_payload_json() -> None:
    event = {
        "event_id": "fr-rte-20260513T181500-consumption",
        "source_system": "rte_eco2mix",
        "country_code": "FR",
        "source_event_time": "2026-05-13T18:15:00Z",
        "ingestion_time": "2026-05-13T18:15:10Z",
        "payload": {"metric_name": "electricity_consumption", "metric_value": 56000.0},
    }

    record = bronze_record_from_event(event)

    assert record["event_date"] == "2026-05-13"
    assert json.loads(record["payload_json"]) == event["payload"]
    assert json.loads(record["raw_event_json"]) == event


def test_parse_bronze_field_extracts_partition_fields() -> None:
    raw_event_json = json.dumps(
        {
            "event_id": "fr-rte-20260513T181500-consumption",
            "source_system": "rte_eco2mix",
            "country_code": "FR",
            "source_event_time": "2026-05-13T18:15:00+00:00",
            "ingestion_time": "2026-05-13T18:15:10Z",
            "payload": {},
        }
    )

    assert parse_bronze_field(raw_event_json, "country_code") == "FR"
    assert parse_bronze_field(raw_event_json, "event_date") == "2026-05-13"


def test_event_date_from_source_time_accepts_zulu_and_offset_timestamps() -> None:
    assert event_date_from_source_time("2026-05-13T18:15:00Z") == "2026-05-13"
    assert event_date_from_source_time("2026-05-13T18:15:00+00:00") == "2026-05-13"


def test_sql_ddl_contains_kafka_sasl_and_s3_parquet_sink() -> None:
    config = BronzeSinkConfig(
        kafka_bootstrap_servers="pkc.example.aws.confluent.cloud:9092",
        kafka_topic="raw.fr.energy_grid",
        kafka_api_key="key",
        kafka_api_secret="secret",
        kafka_group_id="energy-market-flink-bronze",
        s3_bronze_uri="s3://bucket/bronze/raw_fr_energy_grid/",
    )

    source = kafka_source_ddl(config)
    sink = bronze_sink_ddl(config)
    insert = insert_sql()

    assert "'connector' = 'kafka'" in source
    assert "'properties.security.protocol' = 'SASL_SSL'" in source
    assert "'format' = 'parquet'" in sink
    assert "s3://bucket/bronze/raw_fr_energy_grid/" in sink
    assert "bronze_field(raw_event_json, 'payload_json')" in insert
