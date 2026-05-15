# 004 - Producer Hardening

## Goal

Harden the France Eco2mix producer before expanding to more countries by adding controlled retries, structured logging, rate limiting, and a scheduled run mode. This batch improves operational reliability for local and Docker-based runs without changing the raw event contract or Kafka topic strategy.

## Delivery Strategy

This batch is implemented on a single delivery branch:

- `feature/producer-hardening`

The branch delivers retries, structured logging, rate limiting, and scheduled mode together because the runtime controls share the same CLI, tests, and container entrypoints.

## Resources

- France producer CLI under `apps/producers/energy_market/producers/france_rte_producer.py`
- Kafka wrapper under `apps/producers/energy_market/producers/common/kafka.py`
- Producer tests under `apps/producers/energy_market/tests/test_france_rte_producer.py`
- Root Make targets:
  - `make kafka-produce-sample-dry-run`
  - `make kafka-produce-real-dry-run`
  - `make kafka-producer-docker-real-dry-run LAST_DAYS=1`
  - `make producer-test`

## Scope

### 1. Retries

Bounded retry behavior is implemented for transient Eco2mix API failures and Kafka publish failures. Retries use `--retry-max-attempts` and `--retry-backoff-seconds`, stop after the configured maximum attempt count, and surface a final non-zero exit when delivery still fails.

### 2. Structured Logging

Structured logs are emitted with `--log-format json|text` and `--log-level`. Log entries include at least:

- producer name
- source system
- topic
- mode such as dry-run or publish
- event counts
- retry attempts
- terminal success or failure state

### 3. Rate Limiting

Producer-side throttling is implemented for both source API fetches and Kafka publishes so the app can avoid sharp traffic spikes during historical replays. The main controls are:

- `--request-rate-limit-per-second`
- `--publish-rate-limit-per-second`

The legacy `--delay-seconds` capability remains supported for publish pacing.

### 4. Scheduled Run Mode

An opt-in scheduled mode lets the producer run continuously on a fixed interval and fetch or publish at each tick. The main controls are:

- `--schedule-interval-seconds`
- `--max-runs`

Scheduled execution supports clean shutdown and preserves dry-run support for local verification.

## Local Setup

Install the Python package with test dependencies:

```bash
python3 -m pip install -e "./apps/producers/energy_market[test]"
```

Before any Kafka publish verification:

```bash
. ./bin/set_env_vars.sh
. ./bin/set_aws_credentials.sh
. ./bin/set_kafka_output_api_keys.sh
```

## Commands

Validate regression safety with the existing test suite:

```bash
make producer-test
```

Validate dry-run behavior after hardening changes:

```bash
make kafka-produce-sample-dry-run
make kafka-produce-real-dry-run
make kafka-produce-scheduled-dry-run LAST_DAYS=1 SCHEDULE_INTERVAL_SECONDS=10 MAX_RUNS=2
make kafka-producer-docker-real-dry-run LAST_DAYS=1
make kafka-producer-docker-scheduled-dry-run LAST_DAYS=1 SCHEDULE_INTERVAL_SECONDS=10 MAX_RUNS=2
```

Example direct CLI verification:

```bash
cd apps/producers/energy_market
python3 -m producers.france_rte_producer \
  --dry-run \
  --last-days 1 \
  --schedule-interval-seconds 10 \
  --max-runs 2 \
  --retry-max-attempts 3 \
  --retry-backoff-seconds 1 \
  --request-rate-limit-per-second 1 \
  --log-format text
```

## Expected Behavior

- Transient source or publish failures trigger bounded retries before the process exits with an error.
- Runtime output is emitted as structured logs instead of only free-form print statements.
- Historical replays can be throttled to a controlled request and publish pace.
- Scheduled mode repeatedly executes the producer loop on a fixed interval until interrupted.
- Existing one-shot dry-run and publish flows remain supported.

## Acceptance Criteria

- The raw Kafka envelope remains unchanged.
- Existing tests still pass, with new focused tests added for retry, logging, rate limiting, and scheduling logic where useful.
- The producer exits non-zero after exhausting retries.
- Scheduled mode can be stopped cleanly without leaving a half-failed run state.
- Local and Docker entrypoints continue to support the France producer workflow.

## Follow-Up Batches

- Add Belgium Elia producer with the hardened producer runtime pattern reused by default.
- Add Australia source ingestion using the same retry, logging, and scheduling conventions.
- Promote producer logs and freshness metrics into the platform observability layer.
