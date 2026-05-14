"""Publish France RTE raw energy-grid events to Kafka."""

from __future__ import annotations

import argparse
import json
from datetime import UTC, datetime, timedelta
from time import sleep
from typing import Any
from urllib.parse import urlencode
from urllib.request import urlopen

from producers.common.kafka import ConfluentKafkaEventProducer, KafkaProducerConfig

ECO2MIX_RECORDS_URL = (
    "https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets/"
    "eco2mix-national-tr/records"
)
DEFAULT_PAGE_SIZE = 100


def generate_sample_france_rte_events(
    count: int,
    base_time: datetime | None = None,
) -> list[dict[str, Any]]:
    if count < 1:
        raise ValueError("count must be greater than zero")

    start_time = (base_time or datetime.now(UTC)).replace(second=0, microsecond=0)
    ingestion_time = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    events: list[dict[str, Any]] = []

    for index in range(count):
        source_event_time = start_time + timedelta(minutes=5 * index)
        source_event_time_text = source_event_time.isoformat().replace("+00:00", "Z")
        timestamp_key = source_event_time.strftime("%Y%m%dT%H%M%S")

        events.append(
            {
                "event_id": f"fr-rte-{timestamp_key}-consumption",
                "source_system": "rte_eco2mix",
                "country_code": "FR",
                "ingestion_time": ingestion_time,
                "source_event_time": source_event_time_text,
                "payload": {
                    "market_region": "FR_NATIONAL",
                    "metric_name": "electricity_consumption",
                    "metric_value": 56000.0 + (index * 125.0),
                    "unit": "MW",
                    "energy_source": None,
                    "source_timezone": "Europe/Paris",
                    "publication_frequency": "5 minutes",
                    "sample_sequence": index + 1,
                },
            }
        )

    return events


def fetch_france_rte_events(count: int) -> list[dict[str, Any]]:
    if count < 1:
        raise ValueError("count must be greater than zero")

    records = _fetch_eco2mix_records(
        where="consommation is not null",
        limit=count,
        offset=0,
    )
    return [eco2mix_record_to_raw_event(record) for record in records]


def fetch_france_rte_events_for_last_days(
    last_days: int,
    now: datetime | None = None,
    page_size: int = DEFAULT_PAGE_SIZE,
) -> list[dict[str, Any]]:
    if last_days < 1:
        raise ValueError("last_days must be greater than zero")
    if page_size < 1:
        raise ValueError("page_size must be greater than zero")

    upper_bound = (now or datetime.now(UTC)).astimezone(UTC).replace(microsecond=0)
    lower_bound = upper_bound - timedelta(days=last_days)
    where = build_last_days_where_clause(lower_bound=lower_bound, upper_bound=upper_bound)

    records: list[dict[str, Any]] = []
    offset = 0
    while True:
        page = _fetch_eco2mix_records(where=where, limit=page_size, offset=offset)
        records.extend(page)
        if len(page) < page_size:
            break
        offset += page_size

    return [eco2mix_record_to_raw_event(record) for record in records]


def build_last_days_where_clause(lower_bound: datetime, upper_bound: datetime) -> str:
    return (
        "consommation is not null "
        f"and date_heure >= '{_opendatasoft_datetime(lower_bound)}' "
        f"and date_heure <= '{_opendatasoft_datetime(upper_bound)}'"
    )


def _fetch_eco2mix_records(where: str, limit: int, offset: int) -> list[dict[str, Any]]:
    params = urlencode(
        {
            "limit": limit,
            "offset": offset,
            "where": where,
            "order_by": "date_heure desc",
            "timezone": "UTC",
        }
    )
    with urlopen(f"{ECO2MIX_RECORDS_URL}?{params}", timeout=30) as response:
        body = response.read().decode("utf-8")

    payload = json.loads(body)
    records = payload.get("results", [])
    if not isinstance(records, list):
        raise RuntimeError("Unexpected Opendatasoft response: results is not a list")

    return records


def eco2mix_record_to_raw_event(record: dict[str, Any]) -> dict[str, Any]:
    source_event_time = _require_text(record, "date_heure")
    timestamp_key = _event_timestamp_key(source_event_time)
    ingestion_time = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")

    return {
        "event_id": f"fr-rte-{timestamp_key}-consumption",
        "source_system": "rte_eco2mix",
        "country_code": "FR",
        "ingestion_time": ingestion_time,
        "source_event_time": source_event_time,
        "payload": {
            "market_region": "FR_NATIONAL",
            "metric_name": "electricity_consumption",
            "metric_value": record.get("consommation"),
            "unit": "MW",
            "energy_source": None,
            "source_timezone": "Europe/Paris",
            "publication_frequency": "15 minutes",
            "nature": record.get("nature"),
            "forecast_d_minus_1_mw": record.get("prevision_j1"),
            "forecast_current_day_mw": record.get("prevision_j"),
            "generation_mw": {
                "fioul": record.get("fioul"),
                "charbon": record.get("charbon"),
                "gaz": record.get("gaz"),
                "nucleaire": record.get("nucleaire"),
                "eolien": record.get("eolien"),
                "solaire": record.get("solaire"),
                "hydraulique": record.get("hydraulique"),
                "pompage": record.get("pompage"),
                "bioenergies": record.get("bioenergies"),
            },
            "physical_exchanges_mw": record.get("ech_physiques"),
            "co2_intensity_g_per_kwh": record.get("taux_co2"),
            "source_fields": dict(record),
            "raw_record": record,
        },
    }


def _require_text(record: dict[str, Any], field_name: str) -> str:
    value = record.get(field_name)
    if not isinstance(value, str) or not value:
        raise RuntimeError(f"Eco2mix record is missing required field: {field_name}")
    return value


def _event_timestamp_key(source_event_time: str) -> str:
    normalized = source_event_time.replace("Z", "+00:00")
    parsed = datetime.fromisoformat(normalized)
    return parsed.astimezone(UTC).strftime("%Y%m%dT%H%M%S")


def _opendatasoft_datetime(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=3, help="Number of events to emit.")
    parser.add_argument(
        "--last-days",
        type=int,
        default=None,
        help="Fetch all measured Eco2mix records from the last N days. Takes precedence over --count.",
    )
    parser.add_argument(
        "--source",
        choices=["api", "sample"],
        default="api",
        help="Fetch real Eco2mix records from the API or use offline sample events.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print events without publishing to Kafka.",
    )
    parser.add_argument(
        "--delay-seconds",
        type=float,
        default=0.0,
        help="Optional delay between Kafka publishes.",
    )
    args = parser.parse_args()

    if args.source == "api" and args.last_days is not None:
        events = fetch_france_rte_events_for_last_days(args.last_days)
    elif args.source == "api":
        events = fetch_france_rte_events(args.count)
    else:
        events = generate_sample_france_rte_events(args.count)

    if args.dry_run:
        for event in events:
            print(json.dumps(event, sort_keys=True))
        return 0

    config = KafkaProducerConfig.from_env()
    producer = ConfluentKafkaEventProducer(config)

    for event in events:
        producer.publish(event)
        if args.delay_seconds > 0:
            sleep(args.delay_seconds)

    producer.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
