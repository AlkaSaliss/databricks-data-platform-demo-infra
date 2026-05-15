from __future__ import annotations

from producers.common.logging import bind_logger, configure_logging
from producers.common.runtime import RateLimiter, RetryPolicy, call_with_retries


def test_call_with_retries_returns_after_transient_failure() -> None:
    attempts = {"count": 0}
    sleeps: list[float] = []
    logger = bind_logger(
        configure_logging(
            logger_name="tests.common_runtime.retry",
            level="INFO",
            log_format="text",
        )
    )

    def flaky_operation() -> str:
        attempts["count"] += 1
        if attempts["count"] == 1:
            raise RuntimeError("temporary failure")
        return "ok"

    result = call_with_retries(
        flaky_operation,
        retry_policy=RetryPolicy(max_attempts=3, backoff_seconds=0.5),
        logger=logger,
        action="test_retry",
        sleeper=sleeps.append,
    )

    assert result == "ok"
    assert attempts["count"] == 2
    assert sleeps == [0.5]


def test_rate_limiter_waits_between_calls() -> None:
    clock_values = iter([0.0, 0.0, 1.0, 2.0])
    sleeps: list[float] = []
    limiter = RateLimiter(
        1.0,
        clock=lambda: next(clock_values),
        sleeper=sleeps.append,
    )

    assert limiter.wait() == 0.0
    assert limiter.wait() == 1.0
    assert limiter.wait() == 0.0
    assert sleeps == [1.0]
