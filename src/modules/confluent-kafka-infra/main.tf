locals {
  environment_display_name            = "${var.prefix}-confluent"
  kafka_cluster_display_name          = "${var.prefix}-kafka"
  producer_service_account_name       = "${var.prefix}-local-producer"
  flink_consumer_service_account_name = "${var.prefix}-flink-consumer"
  cluster_admin_service_account_name  = "${var.prefix}-cluster-admin"
}

resource "confluent_environment" "this" {
  display_name = local.environment_display_name
}

resource "confluent_kafka_cluster" "this" {
  display_name = local.kafka_cluster_display_name
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.region
  basic {}

  environment {
    id = confluent_environment.this.id
  }
}

resource "confluent_service_account" "cluster_admin" {
  display_name = local.cluster_admin_service_account_name
  description  = "Service account used by Terraform to manage Kafka topics and ACLs for ${var.prefix}."
}

resource "confluent_role_binding" "cluster_admin" {
  principal   = "User:${confluent_service_account.cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.this.rbac_crn
}

resource "confluent_api_key" "cluster_admin" {
  display_name = "${local.cluster_admin_service_account_name}-kafka-api-key"
  description  = "Kafka API key used by Terraform to manage Kafka topics and ACLs for ${var.prefix}."

  owner {
    id          = confluent_service_account.cluster_admin.id
    api_version = confluent_service_account.cluster_admin.api_version
    kind        = confluent_service_account.cluster_admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.this.id
    api_version = confluent_kafka_cluster.this.api_version
    kind        = confluent_kafka_cluster.this.kind

    environment {
      id = confluent_environment.this.id
    }
  }

  depends_on = [
    confluent_role_binding.cluster_admin
  ]
}

resource "confluent_kafka_topic" "producer_mvp" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  topic_name       = var.topic_name
  partitions_count = var.topic_partitions_count
  rest_endpoint    = confluent_kafka_cluster.this.rest_endpoint

  config = {
    "retention.ms" = var.topic_retention_ms
  }

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_service_account" "producer" {
  display_name = local.producer_service_account_name
  description  = "Service account for local producers publishing to ${var.topic_name}."
}

resource "confluent_api_key" "producer" {
  display_name = "${local.producer_service_account_name}-kafka-api-key"
  description  = "Kafka API key for local producers publishing to ${var.topic_name}."

  owner {
    id          = confluent_service_account.producer.id
    api_version = confluent_service_account.producer.api_version
    kind        = confluent_service_account.producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.this.id
    api_version = confluent_kafka_cluster.this.api_version
    kind        = confluent_kafka_cluster.this.kind

    environment {
      id = confluent_environment.this.id
    }
  }
}

resource "confluent_kafka_acl" "producer_describe_cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.producer.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_kafka_acl" "producer_describe_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.producer_mvp.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.producer.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_kafka_acl" "producer_write_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.producer_mvp.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_service_account" "flink_consumer" {
  display_name = local.flink_consumer_service_account_name
  description  = "Service account for local Flink jobs consuming from ${var.topic_name}."
}

resource "confluent_api_key" "flink_consumer" {
  display_name = "${local.flink_consumer_service_account_name}-kafka-api-key"
  description  = "Kafka API key for local Flink jobs consuming from ${var.topic_name}."

  owner {
    id          = confluent_service_account.flink_consumer.id
    api_version = confluent_service_account.flink_consumer.api_version
    kind        = confluent_service_account.flink_consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.this.id
    api_version = confluent_kafka_cluster.this.api_version
    kind        = confluent_kafka_cluster.this.kind

    environment {
      id = confluent_environment.this.id
    }
  }
}

resource "confluent_kafka_acl" "flink_consumer_describe_cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink_consumer.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_kafka_acl" "flink_consumer_describe_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.producer_mvp.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink_consumer.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_kafka_acl" "flink_consumer_read_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.producer_mvp.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}

resource "confluent_kafka_acl" "flink_consumer_read_group" {
  kafka_cluster {
    id = confluent_kafka_cluster.this.id
  }

  resource_type = "GROUP"
  resource_name = var.flink_consumer_group_id
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.flink_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.this.rest_endpoint

  credentials {
    key    = confluent_api_key.cluster_admin.id
    secret = confluent_api_key.cluster_admin.secret
  }
}
