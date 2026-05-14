from __future__ import annotations

import argparse
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Mapping

import yaml


CONFIG_DIR = Path(__file__).resolve().parents[2] / "configs"
DEFAULT_CONFIG_FILES = (
    "confluent.example.yml",
    "s3.example.yml",
    "databricks.example.yml",
)


class ConfigError(Exception):
    """Raised when required configuration cannot be resolved safely."""

    def __init__(self, missing_variables: list[str]) -> None:
        self.missing_variables = sorted(set(missing_variables))
        message = "Missing required environment variables: " + ", ".join(
            self.missing_variables
        )
        super().__init__(message)


@dataclass(frozen=True)
class DemoConfig:
    confluent: dict[str, Any]
    aws: dict[str, Any]
    s3: dict[str, Any]
    databricks: dict[str, Any]


def _load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"Config file must contain a mapping: {path}")
    return data


def _resolve_node(node: Any, environ: Mapping[str, str], missing: list[str]) -> Any:
    if isinstance(node, dict):
        env_name = node.get("env")
        if isinstance(env_name, str):
            value = environ.get(env_name)
            if value:
                return value
            if "default" in node:
                return node["default"]
            if node.get("optional") is True:
                return None
            missing.append(env_name)
            return None
        return {
            key: _resolve_node(value, environ, missing)
            for key, value in node.items()
            if key not in {"optional"}
        }
    if isinstance(node, list):
        return [_resolve_node(item, environ, missing) for item in node]
    return node


def load_config(
    config_dir: Path | str = CONFIG_DIR,
    environ: Mapping[str, str] | None = None,
) -> DemoConfig:
    env = os.environ if environ is None else environ
    base_dir = Path(config_dir)
    merged: dict[str, Any] = {}
    for file_name in DEFAULT_CONFIG_FILES:
        merged.update(_load_yaml(base_dir / file_name))

    missing: list[str] = []
    resolved = _resolve_node(merged, env, missing)
    if missing:
        raise ConfigError(missing)

    return DemoConfig(
        confluent=resolved["confluent"],
        aws=resolved["aws"],
        s3=resolved["s3"],
        databricks=resolved["databricks"],
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate demo configuration.")
    parser.add_argument("--config-dir", default=str(CONFIG_DIR))
    args = parser.parse_args(argv)

    try:
        load_config(args.config_dir)
    except ConfigError as exc:
        print(str(exc))
        return 1

    print("Configuration is valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
