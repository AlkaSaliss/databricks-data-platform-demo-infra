#!/bin/sh

if ! (return 0 2>/dev/null); then
  echo "This script must be sourced to update the current shell session." >&2
  echo "Usage: . ./bin/set_kafka_output_api_keys.sh" >&2
  exit 1
fi

echo "Exporting Kafka output API keys to the current shell..."

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

if [ ! -f "${KAFKA_STACK_DIR}/terragrunt.hcl" ]; then
  echo "Error: Kafka Terragrunt stack not found: ${KAFKA_STACK_DIR}" >&2
  return 1 2>/dev/null || exit 1
fi

kafka_output() {
  (cd "${KAFKA_STACK_DIR}" && terragrunt output -raw "$1")
}

KAFKA_BOOTSTRAP_SERVERS_VALUE="$(kafka_output kafka_bootstrap_endpoint)" || return 1
KAFKA_TOPIC_VALUE="$(kafka_output topic_name)" || return 1
KAFKA_API_KEY_VALUE="$(kafka_output producer_kafka_api_key)" || return 1
KAFKA_API_SECRET_VALUE="$(kafka_output producer_kafka_api_secret)" || return 1

export ENERGY_MARKET_KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS_VALUE}"
export ENERGY_MARKET_KAFKA_TOPIC="${KAFKA_TOPIC_VALUE}"
export ENERGY_MARKET_KAFKA_API_KEY="${KAFKA_API_KEY_VALUE}"
export ENERGY_MARKET_KAFKA_API_SECRET="${KAFKA_API_SECRET_VALUE}"

# Avoid colliding with Confluent Terraform provider environment variables.
unset KAFKA_BOOTSTRAP_SERVERS
unset KAFKA_TOPIC
unset KAFKA_API_KEY
unset KAFKA_API_SECRET

unset KAFKA_BOOTSTRAP_SERVERS_VALUE
unset KAFKA_TOPIC_VALUE
unset KAFKA_API_KEY_VALUE
unset KAFKA_API_SECRET_VALUE

echo "Kafka output API keys exported to the current shell."
