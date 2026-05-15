terraform {
  source = "../../../../modules/confluent-kafka-infra"
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

inputs = {
  environment                = include.env.locals.environment
  region                     = include.region.locals.aws_region
  prefix                     = "energy-market-demo-${include.env.locals.environment}"
  confluent_cloud_api_key    = include.env.locals.confluent_cloud_api_key
  confluent_cloud_api_secret = include.env.locals.confluent_cloud_api_secret
  topic_name                 = "raw.fr.energy_grid"
  topic_partitions_count     = 1
  topic_retention_ms         = "604800000"
  flink_consumer_group_id    = "energy-market-flink-bronze"
}
