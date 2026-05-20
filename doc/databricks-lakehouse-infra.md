# Databricks Lakehouse Infrastructure

This stack creates the Unity Catalog objects that expose the Flink streaming lake bucket to Databricks and prepare the demo lakehouse namespace.

## Resources

- Catalog: `energy_market_demo`
- Schemas: `bronze`, `silver`, `gold`
- AWS IAM role and read-only policy for the streaming lake S3 bucket
- Unity Catalog storage credential
- Unity Catalog external location
- External volume: `energy_market_demo.bronze.streaming_lake`

## Outputs

- `catalog_name`
- `bronze_schema_name`
- `silver_schema_name`
- `gold_schema_name`
- `storage_credential_name`
- `external_location_name`
- `volume_name`
- `volume_path`
- `raw_fr_energy_grid_volume_path`

## Usage

Deploy this stack after `workspace-infra` and `streaming-lake-infra`:

```bash
make plan STACK=databricks-lakehouse-infra
make deploy STACK=databricks-lakehouse-infra
```

The external volume exposes the streaming lake bucket at:

```text
/Volumes/energy_market_demo/bronze/streaming_lake
```

The Databricks pipeline reads the Flink raw bronze files from:

```text
/Volumes/energy_market_demo/bronze/streaming_lake/bronze/raw_fr_energy_grid/
```

## Notes

The IAM policy is read-only because Databricks uses this bucket only as the source of truth for Auto Loader. The managed bronze, silver, and gold tables are written by Lakeflow into Unity Catalog managed storage.

## GitHub Actions

The `Databricks Lakehouse Pipeline` workflow validates and plans this stack on pull requests that touch lakehouse infra or bundle files. Manual runs support `plan`, `apply`, `destroy`, `deploy-bundle`, and `run-pipeline`.

Configure `DATABRICKS_HOST` as a GitHub Environment variable for bundle validation and deployment. The workflow also uses the existing AWS and Databricks client secrets.
