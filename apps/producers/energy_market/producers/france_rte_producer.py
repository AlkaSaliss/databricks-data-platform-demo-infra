"""Publish France RTE raw energy-grid events to Kafka."""

from __future__ import annotations

import argparse
import json
import os
from datetime import UTC, date, datetime, time, timedelta
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
ECO2MIX_CONSOLIDATED_RECORDS_URL = (
    "https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets/"
    "eco2mix-national-cons-def/records"
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


def iso_date(raw_value: str) -> date:
    try:
        return date.fromisoformat(raw_value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("date must use YYYY-MM-DD format") from exc


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


def fetch_france_rte_events_for_backfill(
    start_date: date,
    end_date: date,
    *,
    page_size: int = DEFAULT_PAGE_SIZE,
    retry_policy: RetryPolicy | None = None,
    rate_limiter: RateLimiter | None = None,
    fetch_page: Callable[[str, int, int], list[dict[str, Any]]] | None = None,
    logger: Any | None = None,
) -> list[dict[str, Any]]:
    if start_date > end_date:
        raise ValueError("backfill_start_date must be on or before backfill_end_date")
    if page_size < 1:
        raise ValueError("page_size must be greater than zero")

    records: list[dict[str, Any]] = []
    effective_fetch_page = fetch_page or _fetch_eco2mix_consolidated_records
    monthly_ranges = iter_monthly_date_ranges(start_date, end_date)
    _emit_backfill_progress(
        logger,
        "Starting Eco2mix consolidated backfill fetch.",
        {
            "backfill_start_date": start_date.isoformat(),
            "backfill_end_date": end_date.isoformat(),
            "chunk_count": len(monthly_ranges),
            "page_size": page_size,
        },
    )
    for chunk_number, (chunk_start_date, chunk_end_date) in enumerate(monthly_ranges, start=1):
        _emit_backfill_progress(
            logger,
            "Fetching Eco2mix consolidated backfill chunk.",
            {
                "chunk_number": chunk_number,
                "chunk_count": len(monthly_ranges),
                "chunk_start_date": chunk_start_date.isoformat(),
                "chunk_end_date": chunk_end_date.isoformat(),
                "page_size": page_size,
                "total_records_so_far": len(records),
            },
        )
        chunk_records = fetch_france_rte_records_for_backfill_range(
            chunk_start_date,
            chunk_end_date,
            page_size=page_size,
            retry_policy=retry_policy,
            rate_limiter=rate_limiter,
            fetch_page=effective_fetch_page,
            logger=logger,
            progress_context={
                "chunk_number": chunk_number,
                "chunk_count": len(monthly_ranges),
                "chunk_start_date": chunk_start_date.isoformat(),
                "chunk_end_date": chunk_end_date.isoformat(),
            },
        )
        records.extend(chunk_records)
        _emit_backfill_progress(
            logger,
            "Completed Eco2mix consolidated backfill chunk.",
            {
                "chunk_number": chunk_number,
                "chunk_count": len(monthly_ranges),
                "chunk_start_date": chunk_start_date.isoformat(),
                "chunk_end_date": chunk_end_date.isoformat(),
                "chunk_records": len(chunk_records),
                "total_records_so_far": len(records),
            },
        )
    _emit_backfill_progress(
        logger,
        "Completed Eco2mix consolidated backfill fetch.",
        {
            "backfill_start_date": start_date.isoformat(),
            "backfill_end_date": end_date.isoformat(),
            "chunk_count": len(monthly_ranges),
            "total_records": len(records),
        },
    )
    return [eco2mix_record_to_raw_event(record) for record in records]


def fetch_france_rte_records_for_backfill_range(
    start_date: date,
    end_date: date,
    *,
    page_size: int = DEFAULT_PAGE_SIZE,
    retry_policy: RetryPolicy | None = None,
    rate_limiter: RateLimiter | None = None,
    fetch_page: Callable[[str, int, int], list[dict[str, Any]]] | None = None,
    logger: Any | None = None,
    progress_context: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    if start_date > end_date:
        raise ValueError("start_date must be on or before end_date")
    if page_size < 1:
        raise ValueError("page_size must be greater than zero")

    where = build_backfill_where_clause(start_date=start_date, end_date=end_date)
    records: list[dict[str, Any]] = []
    offset = 0
    effective_fetch_page = fetch_page or _fetch_eco2mix_consolidated_records
    context_base = dict(progress_context or {})
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
        _emit_backfill_progress(
            logger,
            "Fetched Eco2mix consolidated backfill page.",
            {
                **context_base,
                "offset": offset,
                "page_size": page_size,
                "records_in_page": len(page),
                "chunk_records_so_far": len(records),
            },
        )
        if len(page) < page_size:
            break
        offset += page_size
    return records


def build_last_days_where_clause(lower_bound: datetime, upper_bound: datetime) -> str:
    return (
        "consommation is not null "
        f"and date_heure >= '{_opendatasoft_datetime(lower_bound)}' "
        f"and date_heure <= '{_opendatasoft_datetime(upper_bound)}'"
    )


def build_backfill_where_clause(start_date: date, end_date: date) -> str:
    if start_date > end_date:
        raise ValueError("start_date must be on or before end_date")
    lower_bound = datetime.combine(start_date, time.min, tzinfo=UTC)
    upper_bound = datetime.combine(end_date, time(23, 59, 59), tzinfo=UTC)
    return (
        "consommation is not null "
        f"and date_heure >= '{_opendatasoft_datetime(lower_bound)}' "
        f"and date_heure <= '{_opendatasoft_datetime(upper_bound)}'"
    )


def iter_monthly_date_ranges(start_date: date, end_date: date) -> list[tuple[date, date]]:
    if start_date > end_date:
        raise ValueError("start_date must be on or before end_date")

    ranges: list[tuple[date, date]] = []
    current_start = start_date
    while current_start <= end_date:
        next_month_start = _first_day_of_next_month(current_start)
        current_end = min(end_date, next_month_start - timedelta(days=1))
        ranges.append((current_start, current_end))
        current_start = next_month_start
    return ranges


def _emit_backfill_progress(logger: Any | None, message: str, context: dict[str, Any]) -> None:
    if logger is not None:
        logger.info(message, extra={"context": context})
        return
    print(f"{message} {json.dumps(context, sort_keys=True)}", flush=True)


def _first_day_of_next_month(value: date) -> date:
    if value.month == 12:
        return date(value.year + 1, 1, 1)
    return date(value.year, value.month + 1, 1)


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


def publish_events_with_producer(
    events: list[dict[str, Any]],
    *,
    producer: ConfluentKafkaEventProducer,
    topic: str,
    retry_policy: RetryPolicy,
    logger: Any,
    rate_limiter: RateLimiter | None = None,
    initial_published_count: int = 0,
) -> int:
    published = initial_published_count
    for event in events:
        if rate_limiter is not None:
            rate_limiter.wait()
        delivery = call_with_retries(
            lambda event=event: producer.publish(event),
            retry_policy=retry_policy,
            logger=logger,
            action="kafka_publish",
            context={"event_id": event["event_id"], "topic": topic},
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
    return published


def run_backfill_mode(
    args: argparse.Namespace,
    *,
    retry_policy: RetryPolicy,
    logger: Any,
    producer_factory: Callable[[KafkaProducerConfig], ConfluentKafkaEventProducer] = ConfluentKafkaEventProducer,
) -> int:
    _validate_backfill_args(args)
    if args.backfill_start_date is None or args.backfill_end_date is None:
        raise ValueError("backfill dates are required")

    request_rate_limiter = (
        RateLimiter(args.request_rate_limit_per_second) if args.request_rate_limit_per_second else None
    )
    publish_rate_limit = _resolve_publish_rate_limit(args)
    publish_rate_limiter = RateLimiter(publish_rate_limit) if publish_rate_limit else None
    monthly_ranges = iter_monthly_date_ranges(args.backfill_start_date, args.backfill_end_date)
    total_events = 0
    producer: ConfluentKafkaEventProducer | None = None
    config: KafkaProducerConfig | None = None
    if not args.dry_run:
        config = KafkaProducerConfig.from_env()
        producer = producer_factory(config)

    _emit_backfill_progress(
        logger,
        "Starting streaming Eco2mix consolidated backfill.",
        {
            "backfill_start_date": args.backfill_start_date.isoformat(),
            "backfill_end_date": args.backfill_end_date.isoformat(),
            "chunk_count": len(monthly_ranges),
            "page_size": DEFAULT_PAGE_SIZE,
            "dry_run": args.dry_run,
        },
    )
    try:
        for chunk_number, (chunk_start_date, chunk_end_date) in enumerate(monthly_ranges, start=1):
            _emit_backfill_progress(
                logger,
                "Fetching streaming Eco2mix consolidated backfill chunk.",
                {
                    "chunk_number": chunk_number,
                    "chunk_count": len(monthly_ranges),
                    "chunk_start_date": chunk_start_date.isoformat(),
                    "chunk_end_date": chunk_end_date.isoformat(),
                    "total_events_so_far": total_events,
                },
            )
            records = fetch_france_rte_records_for_backfill_range(
                chunk_start_date,
                chunk_end_date,
                retry_policy=retry_policy,
                rate_limiter=request_rate_limiter,
                logger=logger,
                progress_context={
                    "chunk_number": chunk_number,
                    "chunk_count": len(monthly_ranges),
                    "chunk_start_date": chunk_start_date.isoformat(),
                    "chunk_end_date": chunk_end_date.isoformat(),
                },
            )
            events = [eco2mix_record_to_raw_event(record) for record in records]
            logger.info(
                "Prepared streaming backfill chunk events.",
                extra={
                    "context": {
                        "chunk_number": chunk_number,
                        "chunk_count": len(monthly_ranges),
                        "chunk_start_date": chunk_start_date.isoformat(),
                        "chunk_end_date": chunk_end_date.isoformat(),
                        "event_count": len(events),
                    }
                },
            )
            if args.dry_run:
                for event in events:
                    print(json.dumps(event, sort_keys=True))
                total_events += len(events)
            else:
                if producer is None or config is None:
                    raise RuntimeError("Kafka producer was not initialized for backfill publish mode")
                total_events = publish_events_with_producer(
                    events,
                    producer=producer,
                    topic=config.topic,
                    retry_policy=retry_policy,
                    logger=logger,
                    rate_limiter=publish_rate_limiter,
                    initial_published_count=total_events,
                )
            _emit_backfill_progress(
                logger,
                "Completed streaming Eco2mix consolidated backfill chunk.",
                {
                    "chunk_number": chunk_number,
                    "chunk_count": len(monthly_ranges),
                    "chunk_start_date": chunk_start_date.isoformat(),
                    "chunk_end_date": chunk_end_date.isoformat(),
                    "chunk_events": len(events),
                    "total_events_so_far": total_events,
                },
            )
    finally:
        if producer is not None:
            producer.flush()

    logger.info("Completed streaming backfill producer execution.", extra={"context": {"event_count": total_events}})
    return total_events


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
    return _fetch_eco2mix_records_from_url(ECO2MIX_RECORDS_URL, where, limit, offset)


def _fetch_eco2mix_consolidated_records(where: str, limit: int, offset: int) -> list[dict[str, Any]]:
    return _fetch_eco2mix_records_from_url(ECO2MIX_CONSOLIDATED_RECORDS_URL, where, limit, offset)


def _fetch_eco2mix_records_from_url(url: str, where: str, limit: int, offset: int) -> list[dict[str, Any]]:
    params = urlencode(
        {
            "limit": limit,
            "offset": offset,
            "where": where,
            "order_by": "date_heure desc",
            "timezone": "UTC",
        }
    )
    timeout_seconds = int(os.environ.get("API_TIMEOUT_SECONDS", "30"))
    with urlopen(f"{url}?{params}", timeout=timeout_seconds) as response:
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
    parser.add_argument(
        "--backfill-start-date",
        type=iso_date,
        default=None,
        help="Fetch historical consolidated Eco2mix records from this UTC date, inclusive, in YYYY-MM-DD format.",
    )
    parser.add_argument(
        "--backfill-end-date",
        type=iso_date,
        default=None,
        help="Fetch historical consolidated Eco2mix records through this UTC date, inclusive, in YYYY-MM-DD format.",
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
    parser.add_argument("--api-timeout-seconds", type=positive_int, default=30)
    parser.add_argument("--retry-backoff-seconds", type=non_negative_float, default=1.0)
    parser.add_argument("--request-rate-limit-per-second", type=positive_float, default=None)
    parser.add_argument("--publish-rate-limit-per-second", type=positive_float, default=None)
    parser.add_argument("--schedule-interval-seconds", type=positive_float, default=None)
    parser.add_argument("--max-runs", type=positive_int, default=None)
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], default="INFO")
    parser.add_argument("--log-format", choices=["json", "text"], default="json")
    return parser


def _validate_backfill_args(args: argparse.Namespace) -> None:
    start_date = args.backfill_start_date
    end_date = args.backfill_end_date
    if (start_date is None) != (end_date is None):
        raise ValueError("--backfill-start-date and --backfill-end-date must be provided together")
    if start_date is not None and end_date is not None and start_date > end_date:
        raise ValueError("--backfill-start-date must be on or before --backfill-end-date")


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = _build_parser()
    args = parser.parse_args(argv)
    os.environ["API_TIMEOUT_SECONDS"] = str(args.api_timeout_seconds)
    try:
        _validate_backfill_args(args)
    except ValueError as exc:
        parser.error(str(exc))
    return args


def _resolve_events(args: argparse.Namespace, retry_policy: RetryPolicy, logger: Any) -> list[dict[str, Any]]:
    _validate_backfill_args(args)
    request_rate_limiter = (
        RateLimiter(args.request_rate_limit_per_second) if args.request_rate_limit_per_second else None
    )
    if args.source == "api" and args.backfill_start_date is not None and args.backfill_end_date is not None:
        return fetch_france_rte_events_for_backfill(
            args.backfill_start_date,
            args.backfill_end_date,
            retry_policy=retry_policy,
            rate_limiter=request_rate_limiter,
            logger=logger,
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


def _is_api_backfill(args: argparse.Namespace) -> bool:
    return args.source == "api" and args.backfill_start_date is not None and args.backfill_end_date is not None


def _resolve_publish_rate_limit(args: argparse.Namespace) -> float | None:
    publish_rate_limit = args.publish_rate_limit_per_second
    if publish_rate_limit is None and args.delay_seconds > 0:
        publish_rate_limit = 1.0 / args.delay_seconds if args.delay_seconds > 0 else None
    return publish_rate_limit


def _run_once(args: argparse.Namespace, logger: Any) -> int:
    retry_policy = RetryPolicy(
        max_attempts=args.retry_max_attempts,
        backoff_seconds=args.retry_backoff_seconds,
    )
    if _is_api_backfill(args):
        return run_backfill_mode(args, retry_policy=retry_policy, logger=logger)

    events = _resolve_events(args, retry_policy, logger)
    logger.info("Prepared producer events.", extra={"context": {"event_count": len(events)}})

    if args.dry_run:
        for event in events:
            print(json.dumps(event, sort_keys=True))
        logger.info("Completed dry-run producer execution.", extra={"context": {"event_count": len(events)}})
        return len(events)

    config = KafkaProducerConfig.from_env()
    publish_rate_limit = _resolve_publish_rate_limit(args)
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
    args = _parse_args()
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
        topic=os.getenv("ENERGY_MARKET_KAFKA_TOPIC", os.getenv("KAFKA_TOPIC", "")),
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
