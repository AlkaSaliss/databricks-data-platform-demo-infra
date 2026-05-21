SHELL := /bin/bash

.PHONY: help env-vars list-stacks list-active-stacks show-config plan deploy deploy-ci apply destroy destroy-ci validate hcl-validate fmt fmt-check clean kafka-export-vars-local flink-export-vars-local all-env-vars-export-local kafka-producer-docker-build kafka-producer-docker-dry-run kafka-producer-docker-real-dry-run kafka-producer-docker-scheduled-dry-run kafka-producer-docker-run kafka-producer-docker-backfill-dry-run kafka-producer-docker-backfill-run producer-test flink-docker-build flink-bronze-dry-run-config flink-bronze-submit flink-bronze-submit-continue flink-bronze-submit-replay flink-test databricks-demo-cleanup databricks-bundle-validate databricks-bundle-deploy databricks-bundle-run plan-all plan-active-all validate-active-all hcl-validate-active-all deploy-all deploy-active-all apply-all destroy-all destroy-active-all

ENV ?= dev
REGION ?= eu-west-1
STACK ?= account-admin
COUNT ?= 3
LAST_DAYS ?= 1
API_TIMEOUT_SECONDS ?= 30
BACKFILL_START_DATE ?=
BACKFILL_END_DATE ?=
PYTHON ?= python3
RETRY_MAX_ATTEMPTS ?= 3
RETRY_BACKOFF_SECONDS ?= 1
REQUEST_RATE_LIMIT_PER_SECOND ?=
PUBLISH_RATE_LIMIT_PER_SECOND ?=
SCHEDULE_INTERVAL_SECONDS ?= 60
MAX_RUNS ?= 2
LOG_LEVEL ?= INFO
LOG_FORMAT ?= json
FLINK_KAFKA_STARTUP_MODE ?= group-offsets

SRC_DIR := src
ENERGY_PRODUCER_APP_DIR := apps/producers/energy_market
ENERGY_FLINK_APP_DIR := apps/flink/energy_market
DATABRICKS_BUNDLE_DIR := databricks/energy_market
LIVE_DIR := $(SRC_DIR)/live/$(ENV)/$(REGION)
STACK_DIR := $(LIVE_DIR)/$(STACK)
PRODUCER_RUNTIME_ARGS := --retry-max-attempts $(RETRY_MAX_ATTEMPTS) --retry-backoff-seconds $(RETRY_BACKOFF_SECONDS) --log-level $(LOG_LEVEL) --log-format $(LOG_FORMAT) $(if $(REQUEST_RATE_LIMIT_PER_SECOND),--request-rate-limit-per-second $(REQUEST_RATE_LIMIT_PER_SECOND),) $(if $(PUBLISH_RATE_LIMIT_PER_SECOND),--publish-rate-limit-per-second $(PUBLISH_RATE_LIMIT_PER_SECOND),)

DEPLOY_ORDER := terraform-state-infra account-admin network-infra uc-metastore-infra streaming-lake-infra workspace-infra
ACTIVE_DEPLOY_ORDER := account-admin network-infra uc-metastore-infra streaming-lake-infra workspace-infra
DESTROY_ORDER := workspace-infra streaming-lake-infra uc-metastore-infra network-infra account-admin terraform-state-infra
ACTIVE_DESTROY_ORDER := workspace-infra uc-metastore-infra network-infra account-admin

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "\nAvailable targets:\n\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-16s %s\n", $$1, $$2} END {printf "\n"}' $(MAKEFILE_LIST)
	@echo "Current defaults: ENV=$(ENV) REGION=$(REGION) STACK=$(STACK)"

env-vars: ## Show environment variables used by the stacks
	@printf '%s\n' \
		'AWS_PROFILE_NAME' \
		'DATABRICKS_ACCOUNT_ID' \
		'DATABRICKS_CLIENT_ID' \
		'DATABRICKS_CLIENT_SECRET' \
		'DATABRICKS_OWNER_EMAIL' \
		'TF_STATE_BUCKET' \
		'TF_STATE_DYNAMODB_TABLE'

list-stacks: ## List available stacks in the selected environment and region
	@printf '%s\n' $(DEPLOY_ORDER)

list-active-stacks: ## List CI/CD stacks, excluding one-time terraform-state-infra bootstrap
	@printf '%s\n' $(ACTIVE_DEPLOY_ORDER)

show-config: ## Show the resolved stack path
	@echo "ENV=$(ENV)"
	@echo "REGION=$(REGION)"
	@echo "STACK=$(STACK)"
	@echo "STACK_DIR=$(STACK_DIR)"

ensure-stack-dir:
	@test -d "$(STACK_DIR)" || (echo "Stack directory not found: $(STACK_DIR)" >&2; exit 1)

plan: ensure-stack-dir ## Run terragrunt plan for one stack
	@cd $(STACK_DIR) && terragrunt plan

deploy: ensure-stack-dir ## Run terragrunt apply for one stack
	@cd $(STACK_DIR) && terragrunt apply

deploy-ci: ensure-stack-dir ## Run non-interactive terragrunt apply for one stack in CI
	@cd $(STACK_DIR) && terragrunt --non-interactive --source-update init -reconfigure && terragrunt --non-interactive apply -auto-approve

apply: deploy ## Alias for deploy

destroy: ensure-stack-dir ## Run terragrunt destroy for one stack
	@cd $(STACK_DIR) && terragrunt --non-interactive --source-update init -reconfigure && terragrunt --non-interactive destroy

destroy-ci: ensure-stack-dir ## Run non-interactive terragrunt destroy for one stack in CI
	@cd $(STACK_DIR) && terragrunt --non-interactive --source-update init -reconfigure && terragrunt --non-interactive destroy -auto-approve

validate: ensure-stack-dir ## Run terragrunt validate for one stack
	@cd $(STACK_DIR) && terragrunt validate

hcl-validate: ensure-stack-dir ## Run terragrunt hcl validate for one stack
	@cd $(STACK_DIR) && terragrunt hcl validate

fmt: ## Format Terragrunt and Terraform files
	@terragrunt hcl format --working-dir=$(SRC_DIR)
	@find $(SRC_DIR) -name '*.tf' -exec terraform fmt {} \;

fmt-check: ## Check Terraform and Terragrunt formatting without rewriting files
	@terragrunt hcl format --check --working-dir=$(SRC_DIR)
	@terraform fmt -check -recursive $(SRC_DIR)

clean: ## Remove Terragrunt and Terraform cache directories
	@find . -type d \( -name '.terragrunt-cache' -o -name '.terraform' \) -prune -exec rm -rf {} + 2>/dev/null || true

kafka-export-vars-local: ## Show commands that export Kafka producer variables from Terraform outputs
	@printf '%s\n' \
		'. ./bin/set_env_vars.sh' \
		'. ./bin/set_aws_credentials.sh' \
		'. ./bin/set_kafka_output_api_keys.sh'

flink-export-vars-local: ## Print source commands for Flink Kafka and S3 variables
	@printf '%s\n' \
		'# Run these commands in your current shell. This target only prints them.' \
		'. ./bin/set_env_vars.sh' \
		'. ./bin/set_aws_credentials.sh' \
		'. ./bin/set_flink_output_vars.sh'

all-env-vars-export-local: ## Set all environment variables for the project
	. ./bin/set_aws_credentials.sh
	. ./bin/set_env_vars.sh
	. ./bin/set_kafka_output_api_keys.sh
	. ./bin/set_flink_output_vars.sh

kafka-producer-docker-build: ## Build the Docker image for the France Eco2mix producer
	@docker compose -f $(ENERGY_PRODUCER_APP_DIR)/compose.yaml --project-directory $(ENERGY_PRODUCER_APP_DIR) build france-eco2mix-producer

kafka-producer-docker-dry-run: ## Run offline sample producer dry-run in Docker
	@docker compose -f $(ENERGY_PRODUCER_APP_DIR)/compose.yaml --project-directory $(ENERGY_PRODUCER_APP_DIR) run --rm france-eco2mix-producer --count $(COUNT) --source sample --dry-run $(PRODUCER_RUNTIME_ARGS)

kafka-producer-docker-real-dry-run: ## Run real last-days Eco2mix producer dry-run in Docker
	@docker compose -f $(ENERGY_PRODUCER_APP_DIR)/compose.yaml --project-directory $(ENERGY_PRODUCER_APP_DIR) run --rm france-eco2mix-producer --last-days $(LAST_DAYS) --dry-run $(PRODUCER_RUNTIME_ARGS)

kafka-producer-docker-scheduled-dry-run: ## Run scheduled last-days Eco2mix dry-run in Docker
	@docker compose -f $(ENERGY_PRODUCER_APP_DIR)/compose.yaml --project-directory $(ENERGY_PRODUCER_APP_DIR) run --rm france-eco2mix-producer --last-days $(LAST_DAYS) --dry-run --schedule-interval-seconds $(SCHEDULE_INTERVAL_SECONDS) --max-runs $(MAX_RUNS) $(PRODUCER_RUNTIME_ARGS)

kafka-producer-docker-run: ## Fetch real last-days Eco2mix data and publish from Docker
	@docker compose -f $(ENERGY_PRODUCER_APP_DIR)/compose.yaml --project-directory $(ENERGY_PRODUCER_APP_DIR) run --rm france-eco2mix-producer --last-days $(LAST_DAYS) $(PRODUCER_RUNTIME_ARGS)

kafka-producer-docker-backfill-dry-run: ## Run historical consolidated Eco2mix backfill dry-run in Docker
	@test -n "$(BACKFILL_START_DATE)" || (echo "Missing BACKFILL_START_DATE, for example 2024-01-01" >&2; exit 1)
	@test -n "$(BACKFILL_END_DATE)" || (echo "Missing BACKFILL_END_DATE, for example 2024-01-31" >&2; exit 1)
	@docker compose -f $(ENERGY_PRODUCER_APP_DIR)/compose.yaml --project-directory $(ENERGY_PRODUCER_APP_DIR) run --rm france-eco2mix-producer --backfill-start-date $(BACKFILL_START_DATE) --backfill-end-date $(BACKFILL_END_DATE) --api-timeout-seconds $(API_TIMEOUT_SECONDS) --dry-run $(PRODUCER_RUNTIME_ARGS)

kafka-producer-docker-backfill-run: ## Fetch historical consolidated Eco2mix data and publish from Docker
	@test -n "$(BACKFILL_START_DATE)" || (echo "Missing BACKFILL_START_DATE, for example 2024-01-01" >&2; exit 1)
	@test -n "$(BACKFILL_END_DATE)" || (echo "Missing BACKFILL_END_DATE, for example 2024-01-31" >&2; exit 1)
	@docker compose -f $(ENERGY_PRODUCER_APP_DIR)/compose.yaml --project-directory $(ENERGY_PRODUCER_APP_DIR) run --rm france-eco2mix-producer --backfill-start-date $(BACKFILL_START_DATE) --backfill-end-date $(BACKFILL_END_DATE) --api-timeout-seconds $(API_TIMEOUT_SECONDS) $(PRODUCER_RUNTIME_ARGS)

producer-test: ## Run Python producer tests
	@cd $(ENERGY_PRODUCER_APP_DIR) && $(PYTHON) -m pytest

flink-docker-build: ## Build the Docker image for local PyFlink jobs
	@docker compose -f $(ENERGY_FLINK_APP_DIR)/compose.yaml --project-directory $(ENERGY_FLINK_APP_DIR) build

flink-bronze-dry-run-config: ## Validate local Flink bronze sink environment variables
	@test -n "$$FLINK_KAFKA_BOOTSTRAP_SERVERS" || (echo "Missing FLINK_KAFKA_BOOTSTRAP_SERVERS. Run: . ./bin/set_flink_output_vars.sh" >&2; exit 1)
	@test -n "$$FLINK_KAFKA_TOPIC" || (echo "Missing FLINK_KAFKA_TOPIC. Run: . ./bin/set_flink_output_vars.sh" >&2; exit 1)
	@test -n "$$FLINK_KAFKA_API_KEY" || (echo "Missing FLINK_KAFKA_API_KEY. Run: . ./bin/set_flink_output_vars.sh" >&2; exit 1)
	@test -n "$$FLINK_KAFKA_API_SECRET" || (echo "Missing FLINK_KAFKA_API_SECRET. Run: . ./bin/set_flink_output_vars.sh" >&2; exit 1)
	@test -n "$$FLINK_S3_BRONZE_URI" || (echo "Missing FLINK_S3_BRONZE_URI. Run: . ./bin/set_flink_output_vars.sh" >&2; exit 1)
	@cd $(ENERGY_FLINK_APP_DIR) && $(PYTHON) -m jobs.raw_fr_energy_grid_to_s3 --dry-run-config

flink-bronze-submit: ## Submit the raw France Kafka-to-S3 bronze PyFlink job to the local Flink cluster
	@FLINK_KAFKA_STARTUP_MODE="$(FLINK_KAFKA_STARTUP_MODE)" docker compose -f $(ENERGY_FLINK_APP_DIR)/compose.yaml --project-directory $(ENERGY_FLINK_APP_DIR) up job-submitter

flink-bronze-submit-continue: ## Submit Flink and continue from committed Kafka consumer-group offsets
	@$(MAKE) --no-print-directory flink-bronze-submit FLINK_KAFKA_STARTUP_MODE=group-offsets

flink-bronze-submit-replay: ## Submit Flink and replay Kafka from the beginning
	@$(MAKE) --no-print-directory flink-bronze-submit FLINK_KAFKA_STARTUP_MODE=earliest-offset

flink-test: ## Run Python Flink job tests
	@cd $(ENERGY_FLINK_APP_DIR) && $(PYTHON) -m pytest

databricks-demo-cleanup: ## Delete demo Lakeflow pipeline tables before workspace teardown
	@ENV="$(ENV)" REGION="$(REGION)" ./bin/cleanup_databricks_demo_objects.sh

databricks-bundle-validate: ## Validate the Databricks Asset Bundle for the energy market pipeline
	@ENV="$(ENV)" REGION="$(REGION)" ./bin/run_databricks_bundle.sh validate -t dev

databricks-bundle-deploy: ## Deploy the Databricks Asset Bundle for the energy market pipeline
	@ENV="$(ENV)" REGION="$(REGION)" ./bin/run_databricks_bundle.sh deploy -t dev

databricks-bundle-run: ## Run the Lakeflow pipeline from the Databricks Asset Bundle
	@ENV="$(ENV)" REGION="$(REGION)" ./bin/run_databricks_bundle.sh run -t dev energy_market_pipeline

plan-all: ## Run plan for all stacks in deployment order
	@for stack in $(DEPLOY_ORDER); do \
		$(MAKE) --no-print-directory plan ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done

plan-active-all: ## Run plan for active stacks in deployment order, excluding terraform-state-infra
	@for stack in $(ACTIVE_DEPLOY_ORDER); do \
		$(MAKE) --no-print-directory plan ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done

validate-active-all: ## Run terraform validate for active stacks, excluding terraform-state-infra
	@for stack in $(ACTIVE_DEPLOY_ORDER); do \
		$(MAKE) --no-print-directory validate ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done

hcl-validate-active-all: ## Run terragrunt hcl validate for active stacks, excluding terraform-state-infra
	@for stack in $(ACTIVE_DEPLOY_ORDER); do \
		$(MAKE) --no-print-directory hcl-validate ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done

deploy-all: ## Run apply for all stacks in deployment order
	@for stack in $(DEPLOY_ORDER); do \
		$(MAKE) --no-print-directory deploy ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done

deploy-active-all: ## Run non-interactive apply for active stacks in deployment order, excluding terraform-state-infra
	@for stack in $(ACTIVE_DEPLOY_ORDER); do \
		$(MAKE) --no-print-directory deploy-ci ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done

apply-all: deploy-all ## Alias for deploy-all

destroy-all: ## Run destroy for all stacks in reverse order
	@for stack in $(DESTROY_ORDER); do \
		$(MAKE) --no-print-directory destroy ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done

destroy-active-all: ## Run non-interactive destroy for active stacks in reverse order, excluding terraform-state-infra
	@$(MAKE) --no-print-directory databricks-demo-cleanup ENV=$(ENV) REGION=$(REGION)
	@for stack in $(ACTIVE_DESTROY_ORDER); do \
		$(MAKE) --no-print-directory destroy-ci ENV=$(ENV) REGION=$(REGION) STACK=$$stack || exit $$?; \
	done
