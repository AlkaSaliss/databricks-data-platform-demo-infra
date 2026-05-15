"""Structured logging helpers for producers."""

from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any


class StructuredLoggerAdapter(logging.LoggerAdapter):
    def process(self, msg: str, kwargs: dict[str, Any]) -> tuple[str, dict[str, Any]]:
        extra = kwargs.setdefault("extra", {})
        context = dict(self.extra)
        context.update(extra.get("context", {}))
        extra["context"] = context
        return msg, kwargs


class JsonLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        context = getattr(record, "context", None)
        if isinstance(context, dict):
            payload.update(context)
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, sort_keys=True)


class TextLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        timestamp = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        base = f"{timestamp} {record.levelname} {record.name}: {record.getMessage()}"
        context = getattr(record, "context", None)
        if not isinstance(context, dict) or not context:
            return base
        context_text = " ".join(f"{key}={value}" for key, value in sorted(context.items()))
        return f"{base} {context_text}"


def configure_logging(*, logger_name: str, level: str, log_format: str) -> logging.Logger:
    logger = logging.getLogger(logger_name)
    logger.handlers.clear()
    logger.propagate = False
    logger.setLevel(getattr(logging, level.upper()))

    handler = logging.StreamHandler(stream=sys.stderr)
    if log_format == "json":
        handler.setFormatter(JsonLogFormatter())
    else:
        handler.setFormatter(TextLogFormatter())

    logger.addHandler(handler)
    return logger


def bind_logger(logger: logging.Logger, **context: Any) -> StructuredLoggerAdapter:
    return StructuredLoggerAdapter(logger, context)
