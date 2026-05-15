#!/bin/sh

if ! (return 0 2>/dev/null); then
  echo "This script must be sourced to update the current shell session." >&2
  echo "Usage: . ./bin/set_flink_output_vars.sh" >&2
  exit 1
fi

echo "Exporting Flink Kafka and S3 output variables to the current shell..."

if ! command -v terragrunt >/dev/null 2>&1; then
  echo "Error: terragrunt is not installed or not available on PATH." >&2
  return 1 2>/dev/null || exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: run this script from inside the repository checkout." >&2
  return 1 2>/dev/null || exit 1
}

ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${REGION:-eu-west-1}"
KAFKA_STACK_DIR="${REPO_ROOT}/src/live/${ENVIRONMENT}/${REGION}/confluent-kafka-infra"
STREAMING_LAKE_STACK_DIR="${REPO_ROOT}/src/live/${ENVIRONMENT}/${REGION}/streaming-lake-infra"

if [ ! -f "${KAFKA_STACK_DIR}/terragrunt.hcl" ]; then
  echo "Error: Kafka Terragrunt stack not found: ${KAFKA_STACK_DIR}" >&2
  return 1 2>/dev/null || exit 1
fi

if [ ! -f "${STREAMING_LAKE_STACK_DIR}/terragrunt.hcl" ]; then
  echo "Error: streaming lake Terragrunt stack not found: ${STREAMING_LAKE_STACK_DIR}" >&2
  return 1 2>/dev/null || exit 1
fi

kafka_output() {
  (cd "${KAFKA_STACK_DIR}" && terragrunt output -raw "$1")
}

streaming_lake_output() {
  (cd "${STREAMING_LAKE_STACK_DIR}" && terragrunt output -raw "$1")
}

FLINK_KAFKA_BOOTSTRAP_SERVERS_VALUE="$(kafka_output kafka_bootstrap_endpoint)" || return 1
FLINK_KAFKA_TOPIC_VALUE="$(kafka_output topic_name)" || return 1
FLINK_KAFKA_API_KEY_VALUE="$(kafka_output flink_consumer_kafka_api_key)" || return 1
FLINK_KAFKA_API_SECRET_VALUE="$(kafka_output flink_consumer_kafka_api_secret)" || return 1
FLINK_KAFKA_GROUP_ID_VALUE="$(kafka_output flink_consumer_group_id)" || return 1
FLINK_S3_BRONZE_URI_VALUE="$(streaming_lake_output raw_fr_energy_grid_bronze_uri)" || return 1

export FLINK_KAFKA_BOOTSTRAP_SERVERS="${FLINK_KAFKA_BOOTSTRAP_SERVERS_VALUE}"
export FLINK_KAFKA_TOPIC="${FLINK_KAFKA_TOPIC_VALUE}"
export FLINK_KAFKA_API_KEY="${FLINK_KAFKA_API_KEY_VALUE}"
export FLINK_KAFKA_API_SECRET="${FLINK_KAFKA_API_SECRET_VALUE}"
export FLINK_KAFKA_GROUP_ID="${FLINK_KAFKA_GROUP_ID_VALUE}"
export FLINK_S3_BRONZE_URI="${FLINK_S3_BRONZE_URI_VALUE}"

unset FLINK_KAFKA_BOOTSTRAP_SERVERS_VALUE
unset FLINK_KAFKA_TOPIC_VALUE
unset FLINK_KAFKA_API_KEY_VALUE
unset FLINK_KAFKA_API_SECRET_VALUE
unset FLINK_KAFKA_GROUP_ID_VALUE
unset FLINK_S3_BRONZE_URI_VALUE

echo "Flink Kafka and S3 output variables exported to the current shell."
