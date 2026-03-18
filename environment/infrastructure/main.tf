terraform {
  required_version = ">= 1.3.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

# Intentionally a no-op environment module.
# vCluster Platform validates the environment infrastructure module even when
# no real infrastructure provisioning is needed (pod-nodes run in-cluster).
resource "null_resource" "noop" {}
