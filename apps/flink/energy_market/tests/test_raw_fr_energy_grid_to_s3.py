from __future__ import annotations

import pytest

from jobs.raw_fr_energy_grid_to_s3 import (
    BronzeSinkConfig,
    FlinkConfigError,
    bronze_insert_sql,
    kafka_source_ddl,
    lake_uri,
    snapshot_insert_sql,
    snapshot_sink_ddl,
    snapshot_view_sql,
    strip_kafka_protocol,
)


def test_config_fails_when_required_env_vars_are_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in [
        "FLINK_KAFKA_BOOTSTRAP_SERVERS",
        "FLINK_KAFKA_TOPIC",
        "FLINK_KAFKA_API_KEY",
        "FLINK_KAFKA_API_SECRET",
        "FLINK_S3_BRONZE_URI",
    ]:
        monkeypatch.delenv(name, raising=False)

    with pytest.raises(FlinkConfigError, match="Missing Flink environment variables"):
        BronzeSinkConfig.from_env()


def test_config_reads_env_vars_and_derives_output_paths(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FLINK_KAFKA_BOOTSTRAP_SERVERS", "SASL_SSL://pkc.example:9092")
    monkeypatch.setenv("FLINK_KAFKA_TOPIC", "raw.fr.energy_grid")
    monkeypatch.setenv("FLINK_KAFKA_API_KEY", "key")
    monkeypatch.setenv("FLINK_KAFKA_API_SECRET", "secret")
    monkeypatch.setenv("FLINK_S3_BRONZE_URI", "s3://bucket/bronze/raw_fr_energy_grid/")

    config = BronzeSinkConfig.from_env()

    assert config.kafka_bootstrap_servers == "pkc.example:9092"
    assert config.kafka_group_id == "energy-market-flink-bronze"
    assert config.kafka_startup_mode == "group-offsets"
    assert config.s3_bronze_uri == "s3://bucket/bronze/raw_fr_energy_grid/"
    assert config.s3_snapshot_uri == "s3://bucket/silver/fr_energy_market_snapshots_15min/"


def test_config_rejects_unknown_kafka_startup_mode(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FLINK_KAFKA_BOOTSTRAP_SERVERS", "SASL_SSL://pkc.example:9092")
    monkeypatch.setenv("FLINK_KAFKA_TOPIC", "raw.fr.energy_grid")
    monkeypatch.setenv("FLINK_KAFKA_API_KEY", "key")
    monkeypatch.setenv("FLINK_KAFKA_API_SECRET", "secret")
    monkeypatch.setenv("FLINK_S3_BRONZE_URI", "s3://bucket/bronze/raw_fr_energy_grid/")
    monkeypatch.setenv("FLINK_KAFKA_STARTUP_MODE", "latest-offset")

    with pytest.raises(FlinkConfigError, match="FLINK_KAFKA_STARTUP_MODE"):
        BronzeSinkConfig.from_env()


def test_small_helpers() -> None:
    assert strip_kafka_protocol("PLAINTEXT://localhost:9092") == "localhost:9092"
    assert lake_uri("s3://bucket/bronze/raw_fr_energy_grid/", "silver/snapshots") == "s3://bucket/silver/snapshots/"
    assert lake_uri("s3://bucket/raw_fr_energy_grid/", "silver/snapshots") == (
        "s3://bucket/raw_fr_energy_grid/silver/snapshots/"
    )


def test_sql_keeps_demo_features_without_forcing_replay() -> None:
    config = BronzeSinkConfig(
        kafka_bootstrap_servers="pkc.example:9092",
        kafka_topic="raw.fr.energy_grid",
        kafka_api_key="key",
        kafka_api_secret="secret",
        kafka_group_id="energy-market-flink-bronze",
        kafka_startup_mode="group-offsets",
        s3_bronze_uri="s3://bucket/bronze/raw_fr_energy_grid/",
    )

    source = kafka_source_ddl(config)
    snapshot_sink = snapshot_sink_ddl(config)
    snapshot_view = snapshot_view_sql()
    snapshot_insert = snapshot_insert_sql()

    assert "'scan.startup.mode' = 'group-offsets'" in source
    assert "'properties.auto.offset.reset' = 'earliest'" in source
    assert "WATERMARK FOR event_time AS event_time - INTERVAL '5' MINUTE" in source
    assert "s3://bucket/silver/fr_energy_market_snapshots_15min/" in snapshot_sink
    assert "JSON_QUERY(raw_event_json, '$.payload')" in bronze_insert_sql()
    assert "renewable_generation_mw" in snapshot_view
    assert "generation_imbalance" in snapshot_insert


def test_kafka_source_can_replay_from_beginning() -> None:
    config = BronzeSinkConfig(
        kafka_bootstrap_servers="pkc.example:9092",
        kafka_topic="raw.fr.energy_grid",
        kafka_api_key="key",
        kafka_api_secret="secret",
        kafka_group_id="energy-market-flink-bronze",
        kafka_startup_mode="earliest-offset",
        s3_bronze_uri="s3://bucket/bronze/raw_fr_energy_grid/",
    )

    assert "'scan.startup.mode' = 'earliest-offset'" in kafka_source_ddl(config)
