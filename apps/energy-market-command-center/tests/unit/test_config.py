from __future__ import annotations

from pathlib import Path

import pytest

from energy_market_command_center.config import ConfigError, load_config, main


CONFIG_DIR = Path(__file__).resolve().parents[2] / "configs"


def complete_env() -> dict[str, str]:
    return {
        "CONFLUENT_BOOTSTRAP_SERVERS": "lkc.example:9092",
        "CONFLUENT_API_KEY": "test-api-key",
        "CONFLUENT_API_SECRET": "test-api-secret",
        "AWS_PROFILE": "demo-profile",
        "ENERGY_DEMO_RAW_S3_BUCKET": "raw-bucket",
        "ENERGY_DEMO_CURATED_S3_BUCKET": "curated-bucket",
        "DATABRICKS_HOST": "https://workspace.example",
        "DATABRICKS_AUTH_TYPE": "pat",
    }


def test_missing_env_vars_report_names_only() -> None:
    with pytest.raises(ConfigError) as exc_info:
        load_config(CONFIG_DIR, environ={"CONFLUENT_API_KEY": "should-not-appear"})

    message = str(exc_info.value)

    assert "CONFLUENT_BOOTSTRAP_SERVERS" in message
    assert "CONFLUENT_API_SECRET" in message
    assert "should-not-appear" not in message


def test_load_config_applies_defaults() -> None:
    config = load_config(CONFIG_DIR, environ=complete_env())

    assert config.confluent["security_protocol"] == "SASL_SSL"
    assert config.confluent["sasl_mechanism"] == "PLAIN"
    assert config.aws["region"] == "eu-west-1"
    assert config.s3["raw"]["prefix"] == "energy-market-command-center/raw"
    assert config.s3["curated_events"]["prefix"] == "energy-market-command-center/curated"
    assert config.databricks["catalog"] == "energy_market_demo"
    assert config.databricks["schemas"] == [
        "bronze",
        "silver",
        "gold",
        "observability",
    ]


def test_optional_databricks_service_principal_fields_default_to_none() -> None:
    config = load_config(CONFIG_DIR, environ=complete_env())

    assert config.databricks["token"] is None
    assert config.databricks["client_id"] is None
    assert config.databricks["client_secret"] is None


def test_validate_config_cli_fails_without_printing_secret_values(capsys: pytest.CaptureFixture[str]) -> None:
    result = main(["--config-dir", str(CONFIG_DIR)])

    captured = capsys.readouterr()
    assert result == 1
    assert "Missing required environment variables" in captured.out
    assert "CONFLUENT_API_SECRET" in captured.out
    assert "placeholder-api-secret" not in captured.out
