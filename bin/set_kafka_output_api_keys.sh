#!/bin/sh

if ! (return 0 2>/dev/null); then
  echo "This script must be sourced to update the current shell session." >&2
  echo "Usage: . ./bin/set_kafka_output_api_keys.sh" >&2
  exit 1
fi

echo "Exporting Kafka output API keys to the current shell..."

export KAFKA_BOOTSTRAP_SERVERS="$(terragrunt output -raw kafka_bootstrap_endpoint)"
export KAFKA_TOPIC="$(terragrunt output -raw topic_name)"
export KAFKA_API_KEY="$(terragrunt output -raw producer_kafka_api_key)"
export KAFKA_API_SECRET="$(terragrunt output -raw producer_kafka_api_secret)"

echo "Kafka output API keys exported to the current shell."