.PHONY: setup lint test validate-config

setup:
	uv sync

lint:
	uv run ruff check src tests

test:
	uv run pytest

validate-config:
	uv run energy-market-validate-config
