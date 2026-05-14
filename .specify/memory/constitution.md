<!--
Sync Impact Report
Version change: template -> 1.0.0
Modified principles:
- PRINCIPLE_1_NAME -> I. Existing Infrastructure Preservation
- PRINCIPLE_2_NAME -> II. Cloud-Backed MVP
- PRINCIPLE_3_NAME -> III. France-First Scope
- PRINCIPLE_4_NAME -> IV. Spec-First Delivery
- PRINCIPLE_5_NAME -> V. Data Platform Correctness and Demo Readiness
Added sections:
- Security and IaC Boundaries
- Delivery Workflow and Quality Gates
Removed sections:
- Placeholder SECTION_2_NAME
- Placeholder SECTION_3_NAME
Templates requiring updates:
- UPDATED .specify/templates/plan-template.md
- UPDATED .specify/templates/spec-template.md
- UPDATED .specify/templates/tasks-template.md
- REVIEWED .specify/templates/commands/*.md (not present)
Runtime guidance docs:
- REVIEWED README.md (no constitution reference required)
- REVIEWED AGENTS.md (no project-specific append required)
Follow-up TODOs:
- None
-->
# Databricks Data Platform Demo Infra Constitution

## Core Principles

### I. Existing Infrastructure Preservation

Existing Terraform and Terragrunt modules under `src/modules` and active stacks under
`src/live` MUST NOT be changed unless a specific approved spec requirement and task
explicitly require the change. Energy Market Command Center work MUST be additive,
isolated from the existing Databricks-on-AWS foundation, and designed so current
workspace, network, account-admin, metastore, and state stacks continue to plan and
apply independently. Any required infrastructure change MUST document the affected
stack boundary, migration impact, and rollback path before implementation.

Rationale: this repository already provisions shared platform infrastructure; demo
work must not create accidental drift or regressions in that foundation.

### II. Cloud-Backed MVP

The MVP MUST use Confluent Cloud for Kafka and AWS S3 for object storage. Local Python
producers MAY run on a developer machine, but local Kafka, Docker Compose Kafka, MinIO,
or other local S3-compatible storage MUST NOT be part of the MVP path. Local-only mocks
MAY be used in tests only when they do not replace the required Confluent Cloud and S3
quickstart and acceptance flow.

Rationale: the interview demo is intended to show integration with real cloud-backed
platform services while reusing the existing Databricks workspace and Unity Catalog
metastore.

### III. France-First Scope

The first implementation MUST process France RTE / ODRÉ éCO2mix data end to end.
Belgium, Australia, and any other market integrations MUST remain documented
extensions until the France pipeline demonstrates ingestion, streaming normalization,
S3 landing, Databricks Bronze/Silver/Gold assets, observability outputs, and a
10-minute technical demo narrative. Shared abstractions are allowed only when they
simplify the France MVP or preserve an explicit future extension point without adding
incomplete multi-country behavior.

Rationale: a complete France pipeline is more valuable than partially implemented
multi-country complexity.

### IV. Spec-First Delivery

Implementation MUST NOT begin until the constitution, feature specification,
implementation plan, contracts, data model, quickstart, and task list exist and have
been reviewed. Each feature MUST use Spec Kit artifacts under `specs/` before code,
Terraform, notebooks, SQL, or workflow assets are added. Generated tasks MUST preserve
traceability from requirements to contracts, data model entities, observability
outputs, and demo validation steps.

Rationale: this project is explicitly designed as a portfolio-grade demo; disciplined
artifacts are part of the deliverable, not overhead.

### V. Data Platform Correctness and Demo Readiness

Streaming and lakehouse behavior MUST be specified before implementation. Flink
processing MUST use event time, explicit watermarks, deterministic deduplication, and
documented late-event handling. Kafka messages, Flink outputs, S3 objects, and
Databricks table schemas MUST have explicit contracts with required fields and
validation rules. Databricks assets MUST follow Bronze, Silver, and Gold layering with
Unity Catalog-compatible names, comments, and ownership assumptions.

Observability MUST be a first-class output: data freshness, invalid records, late
events, processing latency, and pipeline status MUST be captured in contracts, data
models, tasks, and demo steps. Every artifact MUST support a clear 10-minute technical
demo narrative covering business context, architecture, streaming, lakehouse,
analytics, and extensibility.

Rationale: the demo must prove both engineering correctness and the ability to explain
platform tradeoffs clearly in an interview.

## Security and IaC Boundaries

Confluent API keys, AWS credentials, Databricks tokens, service principal secrets, and
other sensitive values MUST NOT be committed. Secrets MUST be supplied through
environment variables, local profiles, GitHub secrets, Databricks secrets, Confluent
secrets, AWS secret managers, or equivalent secure mechanisms. Example files MUST use
placeholder values and safe naming such as `.example.yml` or `.env.example`.

Any cloud resources required for the demo MUST either reuse existing infrastructure
outputs or be defined as additive Terraform/Terragrunt code with clear ownership and
boundaries. New modules or stacks MUST NOT mutate existing modules by default. If a
spec requires changes under `src/modules` or `src/live`, the plan MUST identify why
reuse or an additive isolated stack is insufficient.

## Delivery Workflow and Quality Gates

Plans MUST include a Constitution Check before Phase 0 research and again after Phase 1
design. The check MUST explicitly verify infrastructure isolation, Confluent Cloud and
S3 usage, France-first scope, secrets safety, streaming correctness, data contracts,
lakehouse layering, observability outputs, demo readiness, MVP simplicity, and IaC
alignment.

Specifications MUST define scope boundaries, required contracts, lakehouse layers,
observability outputs, and success criteria for the France MVP. Task lists MUST create
artifacts before implementation tasks and MUST include validation tasks for contracts,
quickstart execution, secret scanning assumptions, infrastructure non-regression, and
the 10-minute demo narrative.

Reviews MUST block changes that bypass Spec Kit artifacts, commit secrets, introduce
local Kafka or MinIO into the MVP path, modify existing infrastructure without an
approved task, or expand implementation beyond France before the MVP is demonstrably
complete.

## Governance

This constitution supersedes conflicting feature plans, implementation shortcuts, and
runtime guidance. Amendments require an explicit constitution update, a semantic
version bump, and a Sync Impact Report documenting affected templates and follow-up
work.

Versioning policy:

- MAJOR: incompatible changes to governance, scope boundaries, or non-negotiable
  principles.
- MINOR: new principles, new required artifact classes, or materially expanded
  delivery gates.
- PATCH: clarifications, wording fixes, and non-semantic refinements.

Compliance review is required for every spec, plan, task list, and implementation
change. If a feature needs an exception, the exception MUST be documented in the plan's
Complexity Tracking section with the rejected simpler alternative and approval
rationale.

**Version**: 1.0.0 | **Ratified**: 2026-05-14 | **Last Amended**: 2026-05-14
