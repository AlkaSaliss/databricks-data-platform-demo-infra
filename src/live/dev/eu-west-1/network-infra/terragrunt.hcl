terraform {
  source = "../../../../modules/network-infra"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

include "region" {
  path   = find_in_parent_folders("region.hcl")
  expose = true
}
