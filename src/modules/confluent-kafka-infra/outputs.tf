output "environment_id" {
  value       = confluent_environment.this.id
  description = "Confluent Cloud environment ID."
}

output "kafka_cluster_id" {
  value       = confluent_kafka_cluster.this.id
  description = "Confluent Kafka cluster ID."
}

output "kafka_bootstrap_endpoint" {
  value       = confluent_kafka_cluster.this.bootstrap_endpoint
  description = "Kafka bootstrap endpoint for producer clients."
}

output "producer_service_account_id" {
  value       = confluent_service_account.producer.id
  description = "Confluent service account ID used by local producers."
}

output "producer_kafka_api_key" {
  value       = confluent_api_key.producer.id
  description = "Kafka API key for local producers."
  sensitive   = true
}

output "producer_kafka_api_secret" {
  value       = confluent_api_key.producer.secret
  description = "Kafka API secret for local producers."
  sensitive   = true
}

output "topic_name" {
  value       = confluent_kafka_topic.producer_mvp.topic_name
  description = "Kafka topic created for the first local producer."
}
