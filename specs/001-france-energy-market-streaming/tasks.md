# Tasks: France Energy Market Streaming Demo

**Input**: Design documents from `/specs/001-france-energy-market-streaming/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Scope**: Generate an implementation backlog only. Do not implement code while
generating this file.

**Task Format**: `- [ ] T### [P?] Description with file path`

Each task includes:

- **Files**: paths to create or modify
- **Dependencies**: prior task IDs
- **Acceptance criteria**: completion signal
- **Test requirement**: required validation
- **Parallel**: whether task can run in parallel

## Phase 0: Repository Integration

- [X] T001 [P] Create demo application directory skeleton in `apps/energy-market-command-center/`
  - **Files**: `apps/energy-market-command-center/README.md`, `apps/energy-market-command-center/src/energy_market_command_center/__init__.py`, `apps/energy-market-command-center/tests/`
  - **Dependencies**: none
  - **Acceptance criteria**: App directory exists and contains only demo-specific files.
  - **Test requirement**: `find apps/energy-market-command-center -maxdepth 3 -type d`
  - **Parallel**: yes

- [X] T002 [P] Create Databricks asset directory skeleton in `databricks/energy-market-command-center/`
  - **Files**: `databricks/energy-market-command-center/notebooks/`, `databricks/energy-market-command-center/sql/`, `databricks/energy-market-command-center/workflows/`
  - **Dependencies**: none
  - **Acceptance criteria**: Databricks assets are isolated from `src/live` and `src/modules`.
  - **Test requirement**: `find databricks/energy-market-command-center -maxdepth 3 -type d`
  - **Parallel**: yes

- [X] T003 Verify existing infrastructure layout remains untouched in `src/live/` and `src/modules/`
  - **Files**: `src/live/`, `src/modules/`
  - **Dependencies**: T001, T002
  - **Acceptance criteria**: No tracked Terraform/Terragrunt module or live stack files are modified by demo setup.
  - **Test requirement**: `git diff -- src/live src/modules`
  - **Parallel**: no

- [X] T004 [P] Add minimal root README pointer to the demo in `README.md`
  - **Files**: `README.md`
  - **Dependencies**: T001, T002
  - **Acceptance criteria**: README mentions the demo path without changing existing infra instructions.
  - **Test requirement**: Manual markdown review.
  - **Parallel**: yes

## Phase 1: Configuration and Secrets Interface

- [ ] T005 Add Python project metadata for uv in `apps/energy-market-command-center/pyproject.toml`
  - **Files**: `apps/energy-market-command-center/pyproject.toml`
  - **Dependencies**: T001
  - **Acceptance criteria**: Python 3.12, pytest, ruff, confluent-kafka, AWS, and Flink-related dependencies are declared.
  - **Test requirement**: `uv sync --locked` once lockfile exists; before lockfile, `uv lock`.
  - **Parallel**: no

- [ ] T006 [P] Add secret-free environment template in `apps/energy-market-command-center/.env.example`
  - **Files**: `apps/energy-market-command-center/.env.example`
  - **Dependencies**: T001
  - **Acceptance criteria**: Required variable names are listed with placeholder values only.
  - **Test requirement**: Secret scan by manual review and `rg 'secret|key|token' apps/energy-market-command-center/.env.example`
  - **Parallel**: yes

- [ ] T007 [P] Define Confluent config template in `apps/energy-market-command-center/configs/confluent.example.yml`
  - **Files**: `apps/energy-market-command-center/configs/confluent.example.yml`
  - **Dependencies**: T001
  - **Acceptance criteria**: Config references env var names for bootstrap, API key, API secret, security protocol, and SASL mechanism.
  - **Test requirement**: Config parser unit test planned in T012.
  - **Parallel**: yes

- [ ] T008 [P] Define AWS/S3 config template in `apps/energy-market-command-center/configs/s3.example.yml`
  - **Files**: `apps/energy-market-command-center/configs/s3.example.yml`
  - **Dependencies**: T001
  - **Acceptance criteria**: Config includes raw/debug bucket or prefix, dedicated curated-events bucket/prefix, region, profile selector, and required partition convention.
  - **Test requirement**: Config parser unit test planned in T012.
  - **Parallel**: yes

- [ ] T009 [P] Define Databricks config assumptions in `apps/energy-market-command-center/configs/databricks.example.yml`
  - **Files**: `apps/energy-market-command-center/configs/databricks.example.yml`
  - **Dependencies**: T001
  - **Acceptance criteria**: Config names `energy_market_demo` catalog and `bronze`, `silver`, `gold`, `observability` schemas.
  - **Test requirement**: Config parser unit test planned in T012.
  - **Parallel**: yes

- [ ] T010 Implement configuration loader and validation in `apps/energy-market-command-center/src/energy_market_command_center/config.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/config.py`
  - **Dependencies**: T006, T007, T008, T009
  - **Acceptance criteria**: Missing env vars produce names of missing variables without printing values.
  - **Test requirement**: Unit tests in T012.
  - **Parallel**: no

- [ ] T011 Add local Makefile targets for setup, lint, test, and config validation in `apps/energy-market-command-center/Makefile`
  - **Files**: `apps/energy-market-command-center/Makefile`
  - **Dependencies**: T005, T010
  - **Acceptance criteria**: Targets exist for `setup`, `lint`, `test`, and `validate-config`.
  - **Test requirement**: `make -C apps/energy-market-command-center validate-config` with placeholder-safe failure.
  - **Parallel**: no

- [ ] T012 [P] Add configuration tests in `apps/energy-market-command-center/tests/unit/test_config.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_config.py`
  - **Dependencies**: T010
  - **Acceptance criteria**: Tests cover missing env vars, placeholder safety, and config defaults.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_config.py`
  - **Parallel**: yes

## Phase 2: France Source Validation

- [ ] T013 [P] Add France source config template in `apps/energy-market-command-center/configs/france-rte-odre.example.yml`
  - **Files**: `apps/energy-market-command-center/configs/france-rte-odre.example.yml`
  - **Dependencies**: T001
  - **Acceptance criteria**: Template identifies RTE / ODRÉ éCO2mix source and replay mode settings.
  - **Test requirement**: Manual config review.
  - **Parallel**: yes

- [ ] T014 Implement RTE / ODRÉ sample fetch client in `apps/energy-market-command-center/src/energy_market_command_center/producers/france_source.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/producers/france_source.py`
  - **Dependencies**: T010, T013
  - **Acceptance criteria**: Client can fetch or load France sample records without transforming business metrics.
  - **Test requirement**: Unit tests with mocked source response in T016.
  - **Parallel**: no

- [ ] T015 Persist non-sensitive sample payloads in `apps/energy-market-command-center/samples/france/eco2mix_sample.jsonl`
  - **Files**: `apps/energy-market-command-center/samples/france/eco2mix_sample.jsonl`
  - **Dependencies**: T014
  - **Acceptance criteria**: At least 20 representative sample records exist and contain no credentials.
  - **Test requirement**: Sample validation test in T016.
  - **Parallel**: no

- [ ] T016 [P] Add France source tests in `apps/energy-market-command-center/tests/unit/test_france_source.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_france_source.py`
  - **Dependencies**: T014, T015
  - **Acceptance criteria**: Tests cover mocked API fetch, sample replay, and unavailable source fallback.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_france_source.py`
  - **Parallel**: yes

- [ ] T017 Document fallback replay mode in `apps/energy-market-command-center/README.md`
  - **Files**: `apps/energy-market-command-center/README.md`
  - **Dependencies**: T015
  - **Acceptance criteria**: README explains live fetch versus replay mode and when to use each.
  - **Test requirement**: Manual markdown review.
  - **Parallel**: no

## Phase 3: Confluent Cloud Kafka Setup

- [ ] T018 [P] Define Kafka topic constants in `apps/energy-market-command-center/src/energy_market_command_center/kafka/topics.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/kafka/topics.py`
  - **Dependencies**: T001
  - **Acceptance criteria**: `raw.fr.energy_grid` is defined as required MVP topic; optional derived topic names are documented.
  - **Test requirement**: Unit test in T021.
  - **Parallel**: yes

- [ ] T019 Implement Confluent client factory in `apps/energy-market-command-center/src/energy_market_command_center/kafka/client.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/kafka/client.py`
  - **Dependencies**: T010, T018
  - **Acceptance criteria**: Producer/admin/consumer config is built from env vars without logging secrets.
  - **Test requirement**: Unit test in T021.
  - **Parallel**: no

- [ ] T020 Add topic validation CLI in `apps/energy-market-command-center/src/energy_market_command_center/cli/validate_topics.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/cli/validate_topics.py`
  - **Dependencies**: T019
  - **Acceptance criteria**: CLI checks required topic availability in Confluent Cloud.
  - **Test requirement**: Mocked admin-client test in T021; optional cloud smoke test gated by env vars.
  - **Parallel**: no

- [ ] T021 [P] Add Kafka config and topic tests in `apps/energy-market-command-center/tests/unit/test_kafka_config.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_kafka_config.py`
  - **Dependencies**: T018, T019, T020
  - **Acceptance criteria**: Tests cover topic constants, secret-safe config, and missing variable errors.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_kafka_config.py`
  - **Parallel**: yes

- [ ] T022 Add producer smoke test plan in `apps/energy-market-command-center/tests/integration/test_confluent_smoke.py`
  - **Files**: `apps/energy-market-command-center/tests/integration/test_confluent_smoke.py`
  - **Dependencies**: T019, T020
  - **Acceptance criteria**: Test is skipped unless Confluent env vars are present and never prints secrets.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/integration/test_confluent_smoke.py`
  - **Parallel**: no

- [ ] T023 Document Confluent Cloud setup in `apps/energy-market-command-center/README.md`
  - **Files**: `apps/energy-market-command-center/README.md`
  - **Dependencies**: T018, T020
  - **Acceptance criteria**: README lists topic names and required env var names only.
  - **Test requirement**: Manual markdown and secret-safety review.
  - **Parallel**: no

## Phase 4: Raw Producer

- [ ] T024 [P] Copy raw event JSON schema into app contracts in `apps/energy-market-command-center/src/energy_market_command_center/contracts/raw-fr-energy-grid.schema.json`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/contracts/raw-fr-energy-grid.schema.json`
  - **Dependencies**: T001
  - **Acceptance criteria**: App contract matches `specs/001-france-energy-market-streaming/contracts/raw-fr-energy-grid.schema.json`.
  - **Test requirement**: Contract sync test in T025.
  - **Parallel**: yes

- [ ] T025 [P] Add raw event contract tests in `apps/energy-market-command-center/tests/contract/test_raw_fr_energy_grid_contract.py`
  - **Files**: `apps/energy-market-command-center/tests/contract/test_raw_fr_energy_grid_contract.py`
  - **Dependencies**: T024, T015
  - **Acceptance criteria**: Sample raw events validate against schema.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/contract/test_raw_fr_energy_grid_contract.py`
  - **Parallel**: yes

- [ ] T026 Implement raw event envelope builder in `apps/energy-market-command-center/src/energy_market_command_center/producers/raw_event.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/producers/raw_event.py`
  - **Dependencies**: T014, T024
  - **Acceptance criteria**: Builder creates stable `event_id`, metadata, and original payload.
  - **Test requirement**: Unit tests in T027.
  - **Parallel**: no

- [ ] T027 [P] Add raw envelope tests in `apps/energy-market-command-center/tests/unit/test_raw_event.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_raw_event.py`
  - **Dependencies**: T026
  - **Acceptance criteria**: Tests cover stable IDs, payload preservation, country/source constants.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_raw_event.py`
  - **Parallel**: yes

- [ ] T028 Implement local France producer CLI in `apps/energy-market-command-center/src/energy_market_command_center/cli/produce_france.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/cli/produce_france.py`
  - **Dependencies**: T019, T026, T027
  - **Acceptance criteria**: CLI publishes sample or fetched France records to `raw.fr.energy_grid`.
  - **Test requirement**: Mocked producer test in T029; optional cloud smoke T022.
  - **Parallel**: no

- [ ] T029 [P] Add producer tests in `apps/energy-market-command-center/tests/unit/test_produce_france.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_produce_france.py`
  - **Dependencies**: T028
  - **Acceptance criteria**: Tests verify topic, key, value, contract validation, and secret-safe logs.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_produce_france.py`
  - **Parallel**: yes

## Phase 5: Flink Normalization

- [ ] T030 [P] Copy normalized event schema into app contracts in `apps/energy-market-command-center/src/energy_market_command_center/contracts/normalized-energy-market-event.schema.json`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/contracts/normalized-energy-market-event.schema.json`
  - **Dependencies**: T001
  - **Acceptance criteria**: App contract matches the Spec Kit normalized schema.
  - **Test requirement**: Contract sync test in T031.
  - **Parallel**: yes

- [ ] T031 [P] Add normalized contract tests in `apps/energy-market-command-center/tests/contract/test_normalized_event_contract.py`
  - **Files**: `apps/energy-market-command-center/tests/contract/test_normalized_event_contract.py`
  - **Dependencies**: T030
  - **Acceptance criteria**: Valid normalized examples pass and missing required fields fail.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/contract/test_normalized_event_contract.py`
  - **Parallel**: yes

- [ ] T032 Implement France normalization mapper in `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/france_normalization.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/france_normalization.py`
  - **Dependencies**: T026, T030
  - **Acceptance criteria**: Mapper emits canonical metric names and `FR_NATIONAL` market region.
  - **Test requirement**: Unit tests in T033.
  - **Parallel**: no

- [ ] T033 [P] Add France normalization tests in `apps/energy-market-command-center/tests/unit/test_france_normalization.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_france_normalization.py`
  - **Dependencies**: T032
  - **Acceptance criteria**: Tests cover consumption, generation by source, renewable metrics, and source payload hash.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_france_normalization.py`
  - **Parallel**: yes

- [ ] T034 Implement event-time and watermark configuration in `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/event_time.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/event_time.py`
  - **Dependencies**: T032
  - **Acceptance criteria**: Watermark strategy uses `source_event_time` and 5-minute max out-of-orderness.
  - **Test requirement**: Unit tests in T035.
  - **Parallel**: no

- [ ] T035 [P] Add event-time tests in `apps/energy-market-command-center/tests/unit/test_event_time.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_event_time.py`
  - **Dependencies**: T034
  - **Acceptance criteria**: Tests cover on-time, out-of-order, and late-event classification.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_event_time.py`
  - **Parallel**: yes

- [ ] T036 Implement validation and deduplication logic in `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/quality.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/quality.py`
  - **Dependencies**: T032, T034
  - **Acceptance criteria**: Logic validates required fields, units, non-negative values, country code, timestamp parseability, and duplicate IDs.
  - **Test requirement**: Unit tests in T037.
  - **Parallel**: no

- [ ] T037 [P] Add quality and dedup tests in `apps/energy-market-command-center/tests/unit/test_quality.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_quality.py`
  - **Dependencies**: T036
  - **Acceptance criteria**: Tests cover invalid records, duplicate replay, and validation rule IDs.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_quality.py`
  - **Parallel**: yes

- [ ] T038 Implement Flink normalization job entrypoint in `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/normalization_job.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/normalization_job.py`
  - **Dependencies**: T019, T032, T034, T036
  - **Acceptance criteria**: Job consumes `raw.fr.energy_grid` and emits normalized, invalid, and late outputs.
  - **Test requirement**: Integration test with local sample records in T039.
  - **Parallel**: no

- [ ] T039 [P] Add normalization integration test in `apps/energy-market-command-center/tests/integration/test_normalization_flow.py`
  - **Files**: `apps/energy-market-command-center/tests/integration/test_normalization_flow.py`
  - **Dependencies**: T038
  - **Acceptance criteria**: Test runs sample records through normalization boundaries without cloud dependency.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/integration/test_normalization_flow.py`
  - **Parallel**: yes

## Phase 6: Flink KPI Aggregation

- [ ] T040 [P] Copy KPI aggregate schema into app contracts in `apps/energy-market-command-center/src/energy_market_command_center/contracts/france-kpi-aggregate.schema.json`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/contracts/france-kpi-aggregate.schema.json`
  - **Dependencies**: T001
  - **Acceptance criteria**: App contract matches Spec Kit KPI schema.
  - **Test requirement**: Contract test in T041.
  - **Parallel**: yes

- [ ] T041 [P] Add KPI aggregate contract tests in `apps/energy-market-command-center/tests/contract/test_france_kpi_contract.py`
  - **Files**: `apps/energy-market-command-center/tests/contract/test_france_kpi_contract.py`
  - **Dependencies**: T040
  - **Acceptance criteria**: Valid KPI aggregate passes and invalid renewable share fails.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/contract/test_france_kpi_contract.py`
  - **Parallel**: yes

- [ ] T042 Implement KPI calculation functions in `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/kpis.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/kpis.py`
  - **Dependencies**: T032, T040
  - **Acceptance criteria**: Functions compute demand, total generation, renewable generation, renewable share, and carbon intensity when source value exists.
  - **Test requirement**: Unit tests in T043.
  - **Parallel**: no

- [ ] T043 [P] Add KPI calculation tests in `apps/energy-market-command-center/tests/unit/test_kpis.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_kpis.py`
  - **Dependencies**: T042
  - **Acceptance criteria**: Tests cover 15-minute windows, renewable share, missing carbon intensity, and count fields.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_kpis.py`
  - **Parallel**: yes

- [ ] T044 Implement KPI aggregation job entrypoint in `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/kpi_aggregation_job.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/kpi_aggregation_job.py`
  - **Dependencies**: T038, T042
  - **Acceptance criteria**: Job computes 15-minute KPI aggregates and emits data quality counts.
  - **Test requirement**: Integration test in T045.
  - **Parallel**: no

- [ ] T045 [P] Add KPI integration test in `apps/energy-market-command-center/tests/integration/test_kpi_flow.py`
  - **Files**: `apps/energy-market-command-center/tests/integration/test_kpi_flow.py`
  - **Dependencies**: T044
  - **Acceptance criteria**: Test validates KPI output for at least 20 sample measurements.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/integration/test_kpi_flow.py`
  - **Parallel**: yes

## Phase 7: AWS S3 Landing

- [ ] T073 Add isolated curated-events storage IaC in `src/live/dev/eu-west-1/energy-market-demo-storage/terragrunt.hcl`
  - **Files**: `src/live/dev/eu-west-1/energy-market-demo-storage/terragrunt.hcl`, `src/modules/energy-market-demo-storage/`
  - **Dependencies**: T003, T008
  - **Acceptance criteria**: Future implementation creates a dedicated curated-events S3 bucket as isolated additive IaC and does not modify existing `src/modules` or active `src/live` stacks.
  - **Test requirement**: Future implementation must run targeted Terragrunt validation for the new isolated stack and `git diff -- src/modules/account-admin src/modules/network-infra src/modules/terraform-state-infra src/modules/uc-metastore-infra src/modules/workspace-infra src/live/dev/eu-west-1/account-admin src/live/dev/eu-west-1/network-infra src/live/dev/eu-west-1/terraform-state-infra src/live/dev/eu-west-1/uc-metastore-infra src/live/dev/eu-west-1/workspace-infra`.
  - **Parallel**: no

- [ ] T046 Implement S3 path builder in `apps/energy-market-command-center/src/energy_market_command_center/storage/s3_paths.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/storage/s3_paths.py`
  - **Dependencies**: T008, T073
  - **Acceptance criteria**: Raw/debug paths use the raw bucket or prefix; curated paths use the dedicated curated-events bucket/prefix; all paths follow `country_code=FR/dataset=<dataset>/event_date=YYYY-MM-DD/`.
  - **Test requirement**: Unit tests in T047.
  - **Parallel**: no

- [ ] T047 [P] Add S3 path tests in `apps/energy-market-command-center/tests/unit/test_s3_paths.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_s3_paths.py`
  - **Dependencies**: T046
  - **Acceptance criteria**: Tests cover raw/debug routing, dedicated curated-events bucket routing, all datasets, and rejection of missing partition fields.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_s3_paths.py`
  - **Parallel**: yes

- [ ] T048 Implement S3 writer abstraction in `apps/energy-market-command-center/src/energy_market_command_center/storage/s3_writer.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/storage/s3_writer.py`
  - **Dependencies**: T046
  - **Acceptance criteria**: Writer supports JSONL for raw/debug and Parquet for analytics outputs.
  - **Test requirement**: Unit tests in T049.
  - **Parallel**: no

- [ ] T049 [P] Add S3 writer tests in `apps/energy-market-command-center/tests/unit/test_s3_writer.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_s3_writer.py`
  - **Dependencies**: T048
  - **Acceptance criteria**: Tests verify format selection and secret-safe error handling with mocked S3 client.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_s3_writer.py`
  - **Parallel**: yes

- [ ] T050 Add S3 permission smoke test in `apps/energy-market-command-center/tests/integration/test_s3_permissions.py`
  - **Files**: `apps/energy-market-command-center/tests/integration/test_s3_permissions.py`
  - **Dependencies**: T048
  - **Acceptance criteria**: Test is skipped unless AWS/S3 env vars are present and validates object write/read/delete in both the raw/debug bucket or prefix and dedicated curated-events bucket/prefix.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/integration/test_s3_permissions.py`
  - **Parallel**: no

- [ ] T051 Wire Flink output writers to S3 in `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/outputs.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/flink_jobs/outputs.py`
  - **Dependencies**: T038, T044, T048
  - **Acceptance criteria**: Normalized, KPI, data quality, late event, and pipeline status outputs target required S3 datasets.
  - **Test requirement**: Integration tests T039 and T045 updated to assert dataset names.
  - **Parallel**: no

## Phase 8: Databricks Bronze Ingestion

- [ ] T052 [P] Add Databricks DDL for catalog and schemas in `databricks/energy-market-command-center/sql/ddl_energy_market_demo.sql`
  - **Files**: `databricks/energy-market-command-center/sql/ddl_energy_market_demo.sql`
  - **Dependencies**: T002
  - **Acceptance criteria**: SQL creates `energy_market_demo` catalog and `bronze`, `silver`, `gold`, `observability` schemas if needed.
  - **Test requirement**: SQL static review against `contracts/databricks-tables.md`.
  - **Parallel**: yes

- [ ] T053 Implement Bronze ingestion notebook in `databricks/energy-market-command-center/notebooks/01_bronze_ingestion.py`
  - **Files**: `databricks/energy-market-command-center/notebooks/01_bronze_ingestion.py`
  - **Dependencies**: T052
  - **Acceptance criteria**: Notebook supports Auto Loader when external location exists and batch S3 read fallback for MVP.
  - **Test requirement**: Notebook static check in T055.
  - **Parallel**: no

- [ ] T054 Add Bronze table contract SQL in `databricks/energy-market-command-center/sql/ddl_bronze.sql`
  - **Files**: `databricks/energy-market-command-center/sql/ddl_bronze.sql`
  - **Dependencies**: T052
  - **Acceptance criteria**: SQL defines `energy_market_demo.bronze.raw_fr_energy_grid` with comments and expected columns.
  - **Test requirement**: SQL static review in T055.
  - **Parallel**: no

- [ ] T055 [P] Add Databricks asset static tests in `apps/energy-market-command-center/tests/unit/test_databricks_assets.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_databricks_assets.py`
  - **Dependencies**: T052, T053, T054
  - **Acceptance criteria**: Tests verify expected catalog/schema/table names and no secrets in notebooks or SQL.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_databricks_assets.py`
  - **Parallel**: yes

## Phase 9: Databricks Silver/Gold

- [ ] T056 Implement Silver model notebook in `databricks/energy-market-command-center/notebooks/02_silver_model.py`
  - **Files**: `databricks/energy-market-command-center/notebooks/02_silver_model.py`
  - **Dependencies**: T053, T054
  - **Acceptance criteria**: Notebook creates conformed `energy_market_demo.silver.energy_market_events`.
  - **Test requirement**: Static checks in T055 extended for Silver table names and comments.
  - **Parallel**: no

- [ ] T057 Add Silver table DDL in `databricks/energy-market-command-center/sql/ddl_silver.sql`
  - **Files**: `databricks/energy-market-command-center/sql/ddl_silver.sql`
  - **Dependencies**: T052
  - **Acceptance criteria**: SQL matches normalized event contract and includes table comments.
  - **Test requirement**: Static checks in T055 extended.
  - **Parallel**: no

- [ ] T058 Implement Gold marts notebook or SQL in `databricks/energy-market-command-center/notebooks/03_gold_marts.sql`
  - **Files**: `databricks/energy-market-command-center/notebooks/03_gold_marts.sql`
  - **Dependencies**: T056, T057
  - **Acceptance criteria**: Asset creates `gold.france_kpi_15min` and `gold.france_business_dashboard`.
  - **Test requirement**: Static checks in T055 extended for Gold table names.
  - **Parallel**: no

- [ ] T059 Add Gold table DDL in `databricks/energy-market-command-center/sql/ddl_gold.sql`
  - **Files**: `databricks/energy-market-command-center/sql/ddl_gold.sql`
  - **Dependencies**: T052
  - **Acceptance criteria**: SQL matches KPI aggregate contract and includes table comments.
  - **Test requirement**: Static checks in T055 extended.
  - **Parallel**: no

- [ ] T060 Implement observability table DDL in `databricks/energy-market-command-center/sql/ddl_observability.sql`
  - **Files**: `databricks/energy-market-command-center/sql/ddl_observability.sql`
  - **Dependencies**: T052
  - **Acceptance criteria**: SQL creates data quality, late event, and pipeline status tables under `energy_market_demo.observability`.
  - **Test requirement**: Static checks in T055 extended.
  - **Parallel**: no

- [ ] T061 Define Databricks workflow asset in `databricks/energy-market-command-center/workflows/energy_market_command_center_job.yml`
  - **Files**: `databricks/energy-market-command-center/workflows/energy_market_command_center_job.yml`
  - **Dependencies**: T053, T056, T058
  - **Acceptance criteria**: Workflow orders Bronze, Silver, then Gold assets and references no secret values.
  - **Test requirement**: Static YAML parse test in T055 extended.
  - **Parallel**: no

## Phase 10: Dashboard SQL

- [ ] T062 Create business overview query in `databricks/energy-market-command-center/sql/dashboard_business_france.sql`
  - **Files**: `databricks/energy-market-command-center/sql/dashboard_business_france.sql`
  - **Dependencies**: T058, T059
  - **Acceptance criteria**: Query returns demand, generation, renewable generation, renewable share, window time, and country.
  - **Test requirement**: Static query name/table check in T064.
  - **Parallel**: no

- [ ] T063 Create observability overview query in `databricks/energy-market-command-center/sql/dashboard_observability.sql`
  - **Files**: `databricks/energy-market-command-center/sql/dashboard_observability.sql`
  - **Dependencies**: T060
  - **Acceptance criteria**: Query returns freshness, invalid count, late count, latency, and pipeline status.
  - **Test requirement**: Static query name/table check in T064.
  - **Parallel**: no

- [ ] T064 [P] Add dashboard SQL static tests in `apps/energy-market-command-center/tests/unit/test_dashboard_sql.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_dashboard_sql.py`
  - **Dependencies**: T062, T063
  - **Acceptance criteria**: Tests verify dashboard queries reference expected Gold and observability tables.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_dashboard_sql.py`
  - **Parallel**: yes

## Phase 11: Demo Runbook

- [ ] T065 Document local commands in `apps/energy-market-command-center/README.md`
  - **Files**: `apps/energy-market-command-center/README.md`
  - **Dependencies**: T011, T028, T038, T044, T051
  - **Acceptance criteria**: README lists setup, lint, test, produce, Flink, S3, and Databricks validation commands.
  - **Test requirement**: Manual markdown review.
  - **Parallel**: no

- [ ] T066 Create 10-minute demo script in `apps/energy-market-command-center/docs/demo-script.md`
  - **Files**: `apps/energy-market-command-center/docs/demo-script.md`
  - **Dependencies**: T062, T063
  - **Acceptance criteria**: Script covers business context, architecture, streaming, lakehouse, analytics, observability, and extensibility.
  - **Test requirement**: Timed dry run target in T068.
  - **Parallel**: no

- [ ] T067 Document expected outputs and screenshot checklist in `apps/energy-market-command-center/docs/expected-outputs.md`
  - **Files**: `apps/energy-market-command-center/docs/expected-outputs.md`
  - **Dependencies**: T062, T063
  - **Acceptance criteria**: Document lists expected Confluent topic, raw/debug S3 partition, dedicated curated-events S3 bucket partitions, Databricks tables, and dashboard query outputs.
  - **Test requirement**: Manual review against quickstart.
  - **Parallel**: no

- [ ] T068 Add demo validation target in `apps/energy-market-command-center/Makefile`
  - **Files**: `apps/energy-market-command-center/Makefile`
  - **Dependencies**: T065, T066, T067
  - **Acceptance criteria**: `make demo-check` validates local docs, config presence, and expected file paths without requiring secrets.
  - **Test requirement**: `make -C apps/energy-market-command-center demo-check`
  - **Parallel**: no

## Phase 12: Extension Placeholders

- [ ] T069 [P] Add Belgium adapter placeholder in `apps/energy-market-command-center/src/energy_market_command_center/producers/belgium_elia_placeholder.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/producers/belgium_elia_placeholder.py`
  - **Dependencies**: T001
  - **Acceptance criteria**: Placeholder states Belgium is out of MVP scope and names future topic `raw.be.energy_grid`.
  - **Test requirement**: Static test in T071.
  - **Parallel**: yes

- [ ] T070 [P] Add Australia adapter placeholder in `apps/energy-market-command-center/src/energy_market_command_center/producers/australia_placeholder.py`
  - **Files**: `apps/energy-market-command-center/src/energy_market_command_center/producers/australia_placeholder.py`
  - **Dependencies**: T001
  - **Acceptance criteria**: Placeholder states Australia is out of MVP scope and names future topic `raw.au.energy_grid`.
  - **Test requirement**: Static test in T071.
  - **Parallel**: yes

- [ ] T071 [P] Add extension placeholder tests in `apps/energy-market-command-center/tests/unit/test_extension_placeholders.py`
  - **Files**: `apps/energy-market-command-center/tests/unit/test_extension_placeholders.py`
  - **Dependencies**: T069, T070
  - **Acceptance criteria**: Tests verify placeholders cannot publish data and clearly mark future scope.
  - **Test requirement**: `uv run pytest apps/energy-market-command-center/tests/unit/test_extension_placeholders.py`
  - **Parallel**: yes

- [ ] T072 Document extension roadmap in `apps/energy-market-command-center/docs/extensions.md`
  - **Files**: `apps/energy-market-command-center/docs/extensions.md`
  - **Dependencies**: T069, T070
  - **Acceptance criteria**: Roadmap explains how Belgium and Australia can reuse the normalized contract after France MVP.
  - **Test requirement**: Manual markdown review.
  - **Parallel**: no

## Dependencies and Execution Order

```text
Phase 0 -> Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5 -> Phase 6
        -> Phase 7 -> Phase 8 -> Phase 9 -> Phase 10 -> Phase 11 -> Phase 12
```

Critical path:

```text
T001 -> T005 -> T010 -> T014 -> T015 -> T019 -> T028 -> T038 -> T044
     -> T073 -> T048 -> T051 -> T053 -> T056 -> T058 -> T062 -> T066 -> T068
```

Infrastructure preservation gate:

```text
T003 must pass before implementation work is considered ready for review.
No task in this backlog modifies src/live or src/modules.
```

## Parallel Execution Examples

Phase 0:

```text
T001, T002, and T004 can proceed in parallel.
```

Phase 1:

```text
T006, T007, T008, and T009 can proceed after T001.
```

Contracts and tests:

```text
T024, T030, T040 can proceed in parallel after T001.
T025, T031, T041 can proceed after their schema copies.
```

Databricks assets:

```text
T052 can proceed after T002 while app code continues.
T054, T057, T059, and T060 can proceed after T052.
```

Extension placeholders:

```text
T069 and T070 can proceed in parallel after T001.
```

## Independent Test Criteria by User Story

**US1 - Demonstrate France Energy Stream**

- Producer publishes sample events to `raw.fr.energy_grid`.
- Flink normalization and KPI jobs process at least 20 sample records.
- S3 partitions exist for raw, normalized, KPI, and observability datasets.
- Databricks Bronze/Silver/Gold tables are queryable.

**US2 - Analyze France Market KPIs**

- Business dashboard SQL returns demand, generation, renewable generation, renewable
  share, window time, and country.

**US3 - Monitor Demo Pipeline Health**

- Observability SQL returns freshness, invalid count, late count, latency, and status.

**US4 - Present the 10-Minute Interview Narrative**

- Demo script covers business context, architecture, streaming, lakehouse, analytics,
  observability, and extension story in 10 minutes.

## MVP Scope

Suggested MVP implementation sequence:

1. Complete Phases 0-4 to prove France source to Confluent Cloud raw topic.
2. Complete Phases 5-7 to prove event-time processing and S3 landing.
3. Complete Phases 8-10 to prove lakehouse and dashboard queries.
4. Complete Phase 11 before presenting.
5. Complete Phase 12 after MVP is stable because it is documentation/placeholder work.

## Format Validation

- All executable tasks use markdown checkbox format.
- Task IDs run from T001 to T073; T073 was added as an explicit curated-events
  bucket task and is a dependency for S3 landing work.
- All task descriptions include file paths.
- Each task includes dependencies, acceptance criteria, test requirement, and parallel status.
- Tasks are dependency-ordered and grouped by requested phase.
