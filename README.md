# vcluster-auto-nodes-pod

Terraform modules for the [vCluster Platform Auto Nodes](https://www.vcluster.com/docs/vcluster/deploy/worker-nodes/private-nodes/auto-nodes/) feature using [pod-node](https://github.com/loft-demos/pod-node) container images as in-cluster worker nodes.

> **Note:** This approach requires a **container-based Kubernetes cluster** (e.g. [vind](https://github.com/loft-demos/vcluster-platform-demo-app-template/tree/main/vind-demo-cluster), [kind](https://kind.sigs.k8s.io/)). Pod-nodes use privileged containers with nested container runtimes (containerd + kubelet inside a pod). This does **not** work on standard VM-based clusters (EKS, GKE, AKS, bare-metal) where the host kernel does not support the required nesting.

## Structure

```text
vcluster-auto-nodes-pod/
├── node/                          # Per-NodeClaim Terraform: creates one pod-node Pod + cloud-init Secret
│   ├── main.tf
│   └── variables.tf
└── environment/                   # Per-environment Terraform: no-op for pod-nodes (runs in-cluster)
    └── infrastructure/
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

## How it works

vCluster Platform's Auto Nodes feature calls the `node` module once per `NodeClaim`. The module:

1. Creates a Kubernetes `Secret` containing cloud-init `user-data` (with pre-pull runcmd injected for pause and kube-proxy images)
2. Creates a privileged `Pod` using the `pod-node` image, which bootstraps itself as a kubelet and joins the vCluster as a worker node

Resource requests and limits are set to match the `NodeType` spec (Guaranteed QoS), so the scheduler sees accurate allocatable resources.

## NodeType sizing

| Name     | CPU   | Memory | Max pods |
|----------|-------|--------|----------|
| a-small  | 500m  | 256Mi  | 10       |
| b-medium | 750m  | 512Mi  | 20       |
| c-large  | 1     | 1Gi    | 30       |

## Usage with vCluster Platform

Reference this repo from a `NodeProvider`:

```yaml
apiVersion: management.loft.sh/v1
kind: NodeProvider
metadata:
  name: pod-node-provider
spec:
  terraform:
    nodeTemplate:
      git:
        repository: https://github.com/loft-demos/vcluster-auto-nodes-pod.git
        subPath: node
    nodeEnvironmentTemplate:
      infrastructure:
        git:
          repository: https://github.com/loft-demos/vcluster-auto-nodes-pod.git
          subPath: environment/infrastructure
    nodeTypes:
      - name: a-small
        resources:
          cpu: "500m"
          memory: "256Mi"
          pods: "10"
        maxCapacity: 8
      - name: b-medium
        resources:
          cpu: "750m"
          memory: "512Mi"
          pods: "20"
        maxCapacity: 4
      - name: c-large
        resources:
          cpu: "1"
          memory: 1Gi
          pods: "30"
        maxCapacity: 2
```
