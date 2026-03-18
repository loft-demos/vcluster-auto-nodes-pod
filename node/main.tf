terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.22.0"
    }
  }
}

provider "kubernetes" {}

locals {
  nodeclaim_name = var.vcluster.nodeClaim.metadata.name
  vcluster_ns    = var.vcluster.namespace

  test_prop          = try(var.vcluster.nodeClaim.spec.properties["test"], null)
  kubernetes_version = try(var.vcluster.kubeVersion, "v1.33.0")

  pre_pull_items = <<-EOT
  - ctr -n k8s.io images pull registry.k8s.io/pause:3.10
  - ctr -n k8s.io images pull registry.k8s.io/kube-proxy:${local.kubernetes_version}
EOT

  user_data_with_prepull = length(split("runcmd:\n", var.vcluster.userData)) > 1 ? replace(
    var.vcluster.userData,
    "runcmd:\n",
    "runcmd:\n${local.pre_pull_items}"
  ) : "${trimspace(var.vcluster.userData)}\nruncmd:\n${local.pre_pull_items}"

  common_labels = merge(
    {
      "app.kubernetes.io/name"     = "pod-node"
      "app.kubernetes.io/part-of"  = "vcluster-auto-nodes"
      "vcluster.loft.sh/nodeclaim" = local.nodeclaim_name
    },
    var.extra_labels,
    local.test_prop != null ? { "test" = tostring(local.test_prop) } : {}
  )

  node_cpu  = tostring(var.vcluster.nodeType.spec.resources.cpu)
  node_mem  = tostring(var.vcluster.nodeType.spec.resources.memory)
  node_pods = tostring(try(var.vcluster.nodeType.spec.resources.pods, 20))
}

############################
# Secret (cloud-init user-data)
############################
resource "kubernetes_secret_v1" "node" {
  metadata {
    name      = "${local.nodeclaim_name}-pod"
    namespace = local.vcluster_ns
    labels    = local.common_labels
  }

  type = "Opaque"

  data = {
    "user-data" = local.user_data_with_prepull
    "meta-data" = "{}"
  }
}

############################
# Pod node
############################
resource "kubernetes_pod_v1" "pod_node" {
  metadata {
    name      = local.nodeclaim_name
    namespace = local.vcluster_ns
    labels    = local.common_labels

    annotations = var.extra_annotations
  }

  spec {
    termination_grace_period_seconds = var.termination_grace_period_seconds

    node_selector = var.node_selector

    dynamic "toleration" {
      for_each = var.tolerations
      content {
        key      = try(toleration.value.key, null)
        operator = try(toleration.value.operator, null)
        value    = try(toleration.value.value, null)
        effect   = try(toleration.value.effect, null)
      }
    }

    container {
      name              = "pod-node"
      image             = var.image
      image_pull_policy = var.image_pull_policy

      env {
        name  = "PODNODE_CPU"
        value = local.node_cpu
      }
      env {
        name  = "PODNODE_MEMORY"
        value = local.node_mem
      }
      env {
        name  = "PODNODE_PODS"
        value = local.node_pods
      }

      security_context {
        privileged = true
      }

      resources {
        requests = {
          cpu    = local.node_cpu
          memory = local.node_mem
        }
        limits = {
          cpu    = local.node_cpu
          memory = local.node_mem
        }
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

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
    ]
  }
}
