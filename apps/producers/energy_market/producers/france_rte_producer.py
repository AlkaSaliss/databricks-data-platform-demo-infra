"""Publish France RTE raw energy-grid events to Kafka."""

from __future__ import annotations

import argparse
import json
import os
from datetime import UTC, datetime, timedelta
from time import sleep
from typing import Any, Callable
from urllib.parse import urlencode
from urllib.request import urlopen

from producers.common.kafka import ConfluentKafkaEventProducer, KafkaProducerConfig
from producers.common.logging import bind_logger, configure_logging
from producers.common.runtime import RateLimiter, RetryPolicy, call_with_retries

ECO2MIX_RECORDS_URL = (
    "https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets/"
    "eco2mix-national-tr/records"
)
DEFAULT_PAGE_SIZE = 100


def positive_int(raw_value: str) -> int:
    value = int(raw_value)
    if value < 1:
        raise argparse.ArgumentTypeError("value must be greater than zero")
    return value


def non_negative_float(raw_value: str) -> float:
    value = float(raw_value)
    if value < 0:
        raise argparse.ArgumentTypeError("value must be non-negative")
    return value


def positive_float(raw_value: str) -> float:
    value = float(raw_value)
    if value <= 0:
        raise argparse.ArgumentTypeError("value must be greater than zero")
    return value


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


def fetch_france_rte_events(
    count: int,
    *,
    retry_policy: RetryPolicy | None = None,
    rate_limiter: RateLimiter | None = None,
    fetch_page: Callable[[str, int, int], list[dict[str, Any]]] | None = None,
    logger: Any | None = None,
) -> list[dict[str, Any]]:
    if count < 1:
        raise ValueError("count must be greater than zero")
    records = _fetch_page_with_resilience(
        where="consommation is not null",
        limit=count,
        offset=0,
        retry_policy=retry_policy,
        rate_limiter=rate_limiter,
        fetch_page=fetch_page or _fetch_eco2mix_records,
        logger=logger,
    )
    return [eco2mix_record_to_raw_event(record) for record in records]


def fetch_france_rte_events_for_last_days(
    last_days: int,
    *,
    now: datetime | None = None,
    page_size: int = DEFAULT_PAGE_SIZE,
    retry_policy: RetryPolicy | None = None,
    rate_limiter: RateLimiter | None = None,
    fetch_page: Callable[[str, int, int], list[dict[str, Any]]] | None = None,
    logger: Any | None = None,
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
    effective_fetch_page = fetch_page or _fetch_eco2mix_records
    while True:
        page = _fetch_page_with_resilience(
            where=where,
            limit=page_size,
            offset=offset,
            retry_policy=retry_policy,
            rate_limiter=rate_limiter,
            fetch_page=effective_fetch_page,
            logger=logger,
        )
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


def publish_events(
    events: list[dict[str, Any]],
    *,
    config: KafkaProducerConfig,
    retry_policy: RetryPolicy,
    logger: Any,
    rate_limiter: RateLimiter | None = None,
    producer_factory: Callable[[KafkaProducerConfig], ConfluentKafkaEventProducer] = ConfluentKafkaEventProducer,
) -> int:
    producer = producer_factory(config)
    published = 0
    for event in events:
        if rate_limiter is not None:
            rate_limiter.wait()
        delivery = call_with_retries(
            lambda event=event: producer.publish(event),
            retry_policy=retry_policy,
            logger=logger,
            action="kafka_publish",
            context={"event_id": event["event_id"], "topic": config.topic},
        )
        published += 1
        logger.info(
            "Published event.",
            extra={
                "context": {
                    "event_id": event["event_id"],
                    "topic": delivery.topic,
                    "partition": delivery.partition,
                    "offset": delivery.offset,
                    "published_count": published,
                }
            },
        )
    producer.flush()
    return published


def run_scheduled_mode(
    *,
    interval_seconds: float,
    max_runs: int | None,
    run_once: Callable[[], int],
    logger: Any,
    sleeper: Callable[[float], None] = sleep,
) -> int:
    completed_runs = 0
    while True:
        completed_runs += 1
        logger.info("Starting scheduled producer run.", extra={"context": {"run_number": completed_runs}})
        run_once()
        if max_runs is not None and completed_runs >= max_runs:
            logger.info("Scheduled producer run limit reached.", extra={"context": {"completed_runs": completed_runs}})
            return completed_runs
        logger.info(
            "Sleeping before next scheduled producer run.",
            extra={"context": {"sleep_seconds": interval_seconds, "completed_runs": completed_runs}},
        )
        sleeper(interval_seconds)


def _fetch_page_with_resilience(
    *,
    where: str,
    limit: int,
    offset: int,
    retry_policy: RetryPolicy | None,
    rate_limiter: RateLimiter | None,
    fetch_page: Callable[[str, int, int], list[dict[str, Any]]],
    logger: Any | None,
) -> list[dict[str, Any]]:
    if rate_limiter is not None:
        rate_limiter.wait()
    if retry_policy is None or logger is None:
        return fetch_page(where, limit, offset)
    return call_with_retries(
        lambda: fetch_page(where, limit, offset),
        retry_policy=retry_policy,
        logger=logger,
        action="eco2mix_fetch",
        context={"limit": limit, "offset": offset},
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


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=positive_int, default=3, help="Number of events to emit.")
    parser.add_argument(
        "--last-days",
        type=positive_int,
        default=None,
        help="Fetch all measured Eco2mix records from the last N days. Takes precedence over --count.",
    )
    parser.add_argument("--source", choices=["api", "sample"], default="api")
    parser.add_argument("--dry-run", action="store_true", help="Print events without publishing to Kafka.")
    parser.add_argument(
        "--delay-seconds",
        type=non_negative_float,
        default=0.0,
        help="Legacy publish delay between events. Prefer --publish-rate-limit-per-second for new runs.",
    )
    parser.add_argument("--retry-max-attempts", type=positive_int, default=3)
    parser.add_argument("--retry-backoff-seconds", type=non_negative_float, default=1.0)
    parser.add_argument("--request-rate-limit-per-second", type=positive_float, default=None)
    parser.add_argument("--publish-rate-limit-per-second", type=positive_float, default=None)
    parser.add_argument("--schedule-interval-seconds", type=positive_float, default=None)
    parser.add_argument("--max-runs", type=positive_int, default=None)
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], default="INFO")
    parser.add_argument("--log-format", choices=["json", "text"], default="json")
    return parser


def _resolve_events(args: argparse.Namespace, retry_policy: RetryPolicy, logger: Any) -> list[dict[str, Any]]:
    request_rate_limiter = (
        RateLimiter(args.request_rate_limit_per_second) if args.request_rate_limit_per_second else None
    )
    if args.source == "api" and args.last_days is not None:
        return fetch_france_rte_events_for_last_days(
            args.last_days,
            retry_policy=retry_policy,
            rate_limiter=request_rate_limiter,
            logger=logger,
        )
    if args.source == "api":
        return fetch_france_rte_events(
            args.count,
            retry_policy=retry_policy,
            rate_limiter=request_rate_limiter,
            logger=logger,
        )
    return generate_sample_france_rte_events(args.count)


def _run_once(args: argparse.Namespace, logger: Any) -> int:
    retry_policy = RetryPolicy(
        max_attempts=args.retry_max_attempts,
        backoff_seconds=args.retry_backoff_seconds,
    )
    events = _resolve_events(args, retry_policy, logger)
    logger.info("Prepared producer events.", extra={"context": {"event_count": len(events)}})

    if args.dry_run:
        for event in events:
            print(json.dumps(event, sort_keys=True))
        logger.info("Completed dry-run producer execution.", extra={"context": {"event_count": len(events)}})
        return len(events)

    config = KafkaProducerConfig.from_env()
    publish_rate_limit = args.publish_rate_limit_per_second
    if publish_rate_limit is None and args.delay_seconds > 0:
        publish_rate_limit = 1.0 / args.delay_seconds if args.delay_seconds > 0 else None
    published = publish_events(
        events,
        config=config,
        retry_policy=retry_policy,
        logger=logger,
        rate_limiter=RateLimiter(publish_rate_limit) if publish_rate_limit else None,
    )
    logger.info("Completed publish producer execution.", extra={"context": {"event_count": published}})
    return published


def main() -> int:
    args = _build_parser().parse_args()
    base_logger = configure_logging(
        logger_name="producers.france_rte_producer",
        level=args.log_level,
        log_format=args.log_format,
    )
    logger = bind_logger(
        base_logger,
        producer="france_rte_producer",
        source_system="rte_eco2mix",
        mode="dry-run" if args.dry_run else "publish",
        topic=os.getenv("KAFKA_TOPIC", ""),
    )

    try:
        if args.schedule_interval_seconds is not None:
            run_scheduled_mode(
                interval_seconds=args.schedule_interval_seconds,
                max_runs=args.max_runs,
                run_once=lambda: _run_once(args, logger),
                logger=logger,
            )
        else:
            _run_once(args, logger)
    except KeyboardInterrupt:
        logger.warning("Producer interrupted.", extra={"context": {"exit_code": 130}})
        return 130

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
