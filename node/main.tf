terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.22.0"
    }
  }
}

provider "kubernetes" {}

############################
# Secret
############################

resource "kubernetes_secret_v1" "node" {
  metadata {
    name      = "${var.vcluster.nodeClaim.metadata.name}-pod"
    namespace = var.vcluster.namespace
  }

  type = "Opaque"

  # Provider expects base64
  data = {
    "user-data" = var.vcluster.userData
    "meta-data" = "{}"
  }
}

############################
# Pod
############################

resource "kubernetes_pod_v1" "pod_node" {
  metadata {
    name      = var.vcluster.nodeClaim.metadata.name
    namespace = var.vcluster.namespace
  }

  spec {
    termination_grace_period_seconds = 1

    container {
      name  = "pod-node"
      image = "ghcr.io/fabiankramm/pod-node:latest"

      security_context {
        privileged = true
      }

      volume_mount {
        name       = "run"
        mount_path = "/run"
      }
      volume_mount {
        name       = "var-containerd"
        mount_path = "/var/lib/containerd"
      }
      volume_mount {
        name       = "var-kubelet"
        mount_path = "/var/lib/kubelet"
      }
      volume_mount {
        name       = "var-vcluster"
        mount_path = "/var/lib/vcluster"
      }
      volume_mount {
        name       = "user-data"
        mount_path = "/var/lib/cloud/seed/nocloud"
        read_only  = true
      }
    }

    volume {
      name = "run"
      empty_dir {}
    }
    volume {
      name = "var-containerd"
      empty_dir {}
    }
    volume {
      name = "var-kubelet"
      empty_dir {}
    }
    volume {
      name = "var-vcluster"
      empty_dir {}
    }
    volume {
      name = "user-data"
      secret {
        secret_name = kubernetes_secret_v1.node.metadata[0].name

        items {
          key  = "user-data"
          path = "user-data"
        }
        items {
          key  = "meta-data"
          path = "meta-data"
        }
      }
    }
  }
}
