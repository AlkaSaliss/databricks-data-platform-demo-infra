from __future__ import annotations

from datetime import UTC, datetime

import pytest

from producers.common.kafka import KafkaConfigError, KafkaDeliveryResult, KafkaProducerConfig
from producers.common.logging import bind_logger, configure_logging
from producers.common.runtime import RetryPolicy
from producers.france_rte_producer import (
    build_last_days_where_clause,
    eco2mix_record_to_raw_event,
    fetch_france_rte_events,
    fetch_france_rte_events_for_last_days,
    generate_sample_france_rte_events,
    publish_events,
    run_scheduled_mode,
)


def test_generated_raw_event_contains_required_envelope_fields() -> None:
    events = generate_sample_france_rte_events(
        1,
        base_time=datetime(2026, 5, 13, 18, 15, tzinfo=UTC),
    )

    event = events[0]

    assert set(event) >= {
        "event_id",
        "source_system",
        "country_code",
        "ingestion_time",
        "source_event_time",
        "payload",
    }
    assert event["event_id"] == "fr-rte-20260513T181500-consumption"
    assert event["payload"]["metric_name"] == "electricity_consumption"
    assert event["payload"]["unit"] == "MW"


def test_france_sample_events_use_expected_source_identity() -> None:
    events = generate_sample_france_rte_events(
        2,
        base_time=datetime(2026, 5, 13, 18, 15, tzinfo=UTC),
    )

    assert [event["country_code"] for event in events] == ["FR", "FR"]
    assert [event["source_system"] for event in events] == ["rte_eco2mix", "rte_eco2mix"]
    assert events[1]["source_event_time"] == "2026-05-13T18:20:00Z"


def test_producer_config_fails_when_env_vars_are_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in [
        "KAFKA_BOOTSTRAP_SERVERS",
        "KAFKA_TOPIC",
        "KAFKA_API_KEY",
        "KAFKA_API_SECRET",
        "ENERGY_MARKET_KAFKA_BOOTSTRAP_SERVERS",
        "ENERGY_MARKET_KAFKA_TOPIC",
        "ENERGY_MARKET_KAFKA_API_KEY",
        "ENERGY_MARKET_KAFKA_API_SECRET",
    ]:
        monkeypatch.delenv(name, raising=False)

    with pytest.raises(KafkaConfigError, match="Missing Kafka environment variables"):
        KafkaProducerConfig.from_env()


def test_eco2mix_api_record_is_mapped_to_raw_event() -> None:
    source_record = {
        "date_heure": "2026-05-14T15:45:00+00:00",
        "nature": "Données temps réel",
        "consommation": 51324,
        "prevision_j1": 52000,
        "prevision_j": 51500,
        "fioul": 180,
        "charbon": 24,
        "gaz": 4120,
        "nucleaire": 36420,
        "eolien": 5980,
        "solaire": 6840,
        "hydraulique": 7420,
        "pompage": -210,
        "bioenergies": 920,
        "ech_physiques": -1850,
        "taux_co2": 35,
        "stockage_batterie": -16,
        "ech_comm_angleterre": -3528,
    }
    event = eco2mix_record_to_raw_event(source_record)

    assert event["event_id"] == "fr-rte-20260514T154500-consumption"
    assert event["source_system"] == "rte_eco2mix"
    assert event["country_code"] == "FR"
    assert event["source_event_time"] == "2026-05-14T15:45:00+00:00"
    assert event["payload"]["metric_value"] == 51324
    assert event["payload"]["generation_mw"]["nucleaire"] == 36420
    assert event["payload"]["co2_intensity_g_per_kwh"] == 35
    assert event["payload"]["source_fields"] == source_record
    assert event["payload"]["source_fields"]["stockage_batterie"] == -16
    assert event["payload"]["source_fields"]["ech_comm_angleterre"] == -3528


def test_last_days_where_clause_uses_lower_and_upper_datetime_bounds() -> None:
    where = build_last_days_where_clause(
        lower_bound=datetime(2026, 5, 13, 12, 0, tzinfo=UTC),
        upper_bound=datetime(2026, 5, 14, 12, 0, tzinfo=UTC),
    )

    assert "consommation is not null" in where
    assert "date_heure >= '2026-05-13T12:00:00Z'" in where
    assert "date_heure <= '2026-05-14T12:00:00Z'" in where


def test_last_days_fetch_combines_paginated_api_records(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[tuple[str, int, int]] = []

    def fake_fetch(where: str, limit: int, offset: int) -> list[dict[str, object]]:
        calls.append((where, limit, offset))
        if offset == 0:
            return [
                {
                    "date_heure": "2026-05-14T12:00:00+00:00",
                    "consommation": 42000,
                }
            ]
        if offset == 1:
            return [
                {
                    "date_heure": "2026-05-14T11:45:00+00:00",
                    "consommation": 41900,
                }
            ]
        return []

    monkeypatch.setattr(
        "producers.france_rte_producer._fetch_eco2mix_records",
        fake_fetch,
    )

    events = fetch_france_rte_events_for_last_days(
        1,
        now=datetime(2026, 5, 14, 12, 0, tzinfo=UTC),
        page_size=1,
    )

    assert [event["payload"]["metric_value"] for event in events] == [42000, 41900]
    assert [call[2] for call in calls] == [0, 1, 2]
    assert all(call[1] == 1 for call in calls)


def test_latest_count_fetch_maps_api_records(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_fetch(where: str, limit: int, offset: int) -> list[dict[str, object]]:
        assert where == "consommation is not null"
        assert limit == 1
        assert offset == 0
        return [
            {
                "date_heure": "2026-05-14T12:00:00+00:00",
                "consommation": 42000,
            }
        ]

    monkeypatch.setattr(
        "producers.france_rte_producer._fetch_eco2mix_records",
        fake_fetch,
    )

    events = fetch_france_rte_events(1)

    assert events[0]["event_id"] == "fr-rte-20260514T120000-consumption"
    assert events[0]["payload"]["metric_value"] == 42000


def test_fetch_retries_transient_api_errors() -> None:
    attempts = {"count": 0}

    def flaky_fetch(where: str, limit: int, offset: int) -> list[dict[str, object]]:
        attempts["count"] += 1
        if attempts["count"] == 1:
            raise RuntimeError("temporary api failure")
        return [
            {
                "date_heure": "2026-05-14T12:00:00+00:00",
                "consommation": 42000,
            }
        ]

    logger = bind_logger(
        configure_logging(
            logger_name="tests.fetch_retry",
            level="INFO",
            log_format="text",
        )
    )

    events = fetch_france_rte_events(
        1,
        retry_policy=RetryPolicy(max_attempts=2, backoff_seconds=0),
        fetch_page=flaky_fetch,
        logger=logger,
    )

    assert attempts["count"] == 2
    assert events[0]["payload"]["metric_value"] == 42000


def test_publish_events_retries_failed_delivery() -> None:
    class FakeProducer:
        def __init__(self, config: KafkaProducerConfig) -> None:
            self.calls = 0

        def publish(self, event: dict[str, object]) -> KafkaDeliveryResult:
            self.calls += 1
            if self.calls == 1:
                raise RuntimeError("broker unavailable")
            return KafkaDeliveryResult(topic="raw.fr.energy_grid", partition=2, offset=9)

        def flush(self) -> None:
            return None

    logger = bind_logger(
        configure_logging(
            logger_name="tests.publish_retry",
            level="INFO",
            log_format="text",
        )
    )

    published = publish_events(
        [generate_sample_france_rte_events(1)[0]],
        config=KafkaProducerConfig(
            bootstrap_servers="localhost:9092",
            topic="raw.fr.energy_grid",
            api_key="key",
            api_secret="secret",
        ),
        retry_policy=RetryPolicy(max_attempts=2, backoff_seconds=0),
        logger=logger,
        producer_factory=FakeProducer,
    )

    assert published == 1


def test_scheduled_mode_runs_until_max_runs() -> None:
    calls: list[str] = []
    sleeps: list[float] = []
    logger = bind_logger(
        configure_logging(
            logger_name="tests.schedule",
            level="INFO",
            log_format="text",
        )
    )

    completed_runs = run_scheduled_mode(
        interval_seconds=5.0,
        max_runs=3,
        run_once=lambda: calls.append("run") or 1,
        logger=logger,
        sleeper=sleeps.append,
    )

    assert completed_runs == 3
    assert calls == ["run", "run", "run"]
    assert sleeps == [5.0, 5.0]
