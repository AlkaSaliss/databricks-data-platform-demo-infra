terraform {
  source = "../../../../modules/network-infra"
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
  prefix     = "network-${include.env.locals.environment}-${include.region.locals.aws_region}"
  cidr_block = "10.1.0.0/16"
}
