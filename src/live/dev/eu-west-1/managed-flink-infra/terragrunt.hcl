terraform {
  source = "../../../../modules/managed-flink-infra"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}

dependency "confluent_kafka" {
  config_path = "../confluent-kafka-infra"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs = {
    kafka_bootstrap_endpoint        = "SASL_SSL://pkc.example.aws.confluent.cloud:9092"
    topic_name                      = "raw.fr.energy_grid"
    flink_consumer_kafka_api_key    = "mock-api-key"
    flink_consumer_kafka_api_secret = "mock-api-secret"
    flink_consumer_group_id         = "energy-market-flink-bronze"
  }
}

dependency "streaming_lake" {
  config_path = "../streaming-lake-infra"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan", "output"]
  mock_outputs = {
    raw_fr_energy_grid_bronze_uri = "s3://energy-market-demo-dev-eu-west-1-streaming-bronze/bronze/raw_fr_energy_grid/"
  }
}

inputs = {
  prefix                  = "energy-market-demo-${include.env.locals.environment}-${include.region.locals.aws_region}-managed-flink"
  application_zip_path    = "${get_terragrunt_dir()}/../../../../../build/managed-flink/raw_fr_energy_grid_to_s3.zip"
  kafka_bootstrap_servers = dependency.confluent_kafka.outputs.kafka_bootstrap_endpoint
  kafka_topic             = dependency.confluent_kafka.outputs.topic_name
  kafka_api_key           = dependency.confluent_kafka.outputs.flink_consumer_kafka_api_key
  kafka_api_secret        = dependency.confluent_kafka.outputs.flink_consumer_kafka_api_secret
  kafka_group_id          = dependency.confluent_kafka.outputs.flink_consumer_group_id
  s3_bronze_uri           = dependency.streaming_lake.outputs.raw_fr_energy_grid_bronze_uri
  start_application       = false
  log_retention_days      = 7
}
