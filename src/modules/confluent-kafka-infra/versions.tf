terraform {
  required_version = ">= 1.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.72.0"
    }
  }
}
