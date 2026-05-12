# network-infra Module

This module creates the AWS network baseline required by the Databricks workspace stack.

## Creates

- VPC
- Public and private subnets
- Default security group configuration
- VPC endpoints for S3, STS, and Kinesis Streams

## Inputs

- `prefix`
- `cidr_block`
- `tags` (optional)

## Outputs

- `vpc_id`
- `subnets`
- `security_group_ids`
- `vpc_main_route_table_id`
- `private_route_table_ids`
