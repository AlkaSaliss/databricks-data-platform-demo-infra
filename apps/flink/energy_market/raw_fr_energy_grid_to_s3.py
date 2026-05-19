"""Root entrypoint for Amazon Managed Service for Apache Flink."""

from __future__ import annotations

from jobs.raw_fr_energy_grid_to_s3 import entrypoint


if __name__ == "__main__":
    raise SystemExit(entrypoint())
