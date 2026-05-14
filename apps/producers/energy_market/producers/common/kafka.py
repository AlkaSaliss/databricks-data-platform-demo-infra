"""Kafka producer wrapper for local Confluent Cloud publishing."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any, Mapping


class KafkaConfigError(RuntimeError):
    """Raised when required Kafka producer configuration is missing."""


@dataclass(frozen=True)
class KafkaProducerConfig:
    bootstrap_servers: str
    topic: str
    api_key: str
    api_secret: str

    @classmethod
    def from_env(cls) -> "KafkaProducerConfig":
        required_vars = {
            "KAFKA_BOOTSTRAP_SERVERS": os.getenv("KAFKA_BOOTSTRAP_SERVERS"),
            "KAFKA_TOPIC": os.getenv("KAFKA_TOPIC"),
            "KAFKA_API_KEY": os.getenv("KAFKA_API_KEY"),
            "KAFKA_API_SECRET": os.getenv("KAFKA_API_SECRET"),
        }
        missing = [name for name, value in required_vars.items() if not value]
        if missing:
            missing_list = ", ".join(missing)
            raise KafkaConfigError(
                "Missing Kafka environment variables: "
                f"{missing_list}. Source bin/set_kafka_output_api_keys.sh first."
            )

        return cls(
            bootstrap_servers=required_vars["KAFKA_BOOTSTRAP_SERVERS"] or "",
            topic=required_vars["KAFKA_TOPIC"] or "",
            api_key=required_vars["KAFKA_API_KEY"] or "",
            api_secret=required_vars["KAFKA_API_SECRET"] or "",
        )


class ConfluentKafkaEventProducer:
    def __init__(self, config: KafkaProducerConfig) -> None:
        try:
            from confluent_kafka import Producer
        except ImportError as exc:
            raise RuntimeError(
                "confluent-kafka is required to publish events. "
                "Install project dependencies before running this command."
            ) from exc

        self._topic = config.topic
        self._delivery_errors: list[Any] = []
        self._producer = Producer(
            {
                "bootstrap.servers": config.bootstrap_servers,
                "security.protocol": "SASL_SSL",
                "sasl.mechanism": "PLAIN",
                "sasl.username": config.api_key,
                "sasl.password": config.api_secret,
                "client.id": "energy-market-local-producer",
            }
        )

    def publish(self, event: Mapping[str, Any]) -> None:
        event_id = str(event["event_id"])
        payload = json.dumps(event, separators=(",", ":"), sort_keys=True).encode("utf-8")
        self._producer.produce(
            self._topic,
            key=event_id.encode("utf-8"),
            value=payload,
            on_delivery=self._delivery_report,
        )
        self._producer.poll(0)

    def flush(self) -> None:
        remaining = self._producer.flush(timeout=30)
        if remaining:
            raise RuntimeError(f"Timed out before {remaining} Kafka message(s) were delivered.")
        if self._delivery_errors:
            errors = "; ".join(str(error) for error in self._delivery_errors)
            raise RuntimeError(f"Kafka delivery failed: {errors}")

    def _delivery_report(self, error: Any, message: Any) -> None:
        if error is not None:
            self._delivery_errors.append(error)
            return

        print(
            "Published event to "
            f"{message.topic()}[{message.partition()}] at offset {message.offset()}"
        )
