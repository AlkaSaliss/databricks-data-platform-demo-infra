"""Runtime helpers for retries and rate limiting."""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any, Callable, TypeVar

T = TypeVar("T")


@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int = 3
    backoff_seconds: float = 1.0

    def __post_init__(self) -> None:
        if self.max_attempts < 1:
            raise ValueError("max_attempts must be greater than zero")
        if self.backoff_seconds < 0:
            raise ValueError("backoff_seconds must be non-negative")


class RateLimiter:
    def __init__(
        self,
        rate_per_second: float,
        *,
        clock: Callable[[], float] = time.monotonic,
        sleeper: Callable[[float], None] = time.sleep,
    ) -> None:
        if rate_per_second <= 0:
            raise ValueError("rate_per_second must be greater than zero")

        self._minimum_interval = 1.0 / rate_per_second
        self._clock = clock
        self._sleeper = sleeper
        self._next_allowed_at: float | None = None

    def wait(self) -> float:
        now = self._clock()
        if self._next_allowed_at is None:
            self._next_allowed_at = now + self._minimum_interval
            return 0.0

        wait_seconds = self._next_allowed_at - now
        if wait_seconds > 0:
            self._sleeper(wait_seconds)
            now = self._clock()

        self._next_allowed_at = max(self._next_allowed_at, now) + self._minimum_interval
        return max(wait_seconds, 0.0)


def call_with_retries(
    operation: Callable[[], T],
    *,
    retry_policy: RetryPolicy,
    logger: Any,
    action: str,
    context: dict[str, Any] | None = None,
    retryable_exceptions: tuple[type[BaseException], ...] = (Exception,),
    sleeper: Callable[[float], None] = time.sleep,
) -> T:
    attempt_context = dict(context or {})

    for attempt in range(1, retry_policy.max_attempts + 1):
        try:
            return operation()
        except retryable_exceptions as exc:
            error_context = {
                **attempt_context,
                "action": action,
                "attempt": attempt,
                "max_attempts": retry_policy.max_attempts,
                "error": str(exc),
            }
            if attempt >= retry_policy.max_attempts:
                logger.error(
                    "Operation failed after retries exhausted.",
                    extra={"context": error_context},
                )
                raise

            wait_seconds = retry_policy.backoff_seconds * attempt
            logger.warning(
                "Operation failed. Retrying.",
                extra={
                    "context": {
                        **error_context,
                        "retry_backoff_seconds": wait_seconds,
                    }
                },
            )
            if wait_seconds > 0:
                sleeper(wait_seconds)

    raise RuntimeError("Retry loop ended unexpectedly")
