variable "image" {
  description = "Container image for the pod-node."
  type        = string
  default     = "ghcr.io/loft-demos/pod-node:0.6.0"
}

variable "image_pull_policy" {
  description = "Always | IfNotPresent | Never"
  type        = string
  default     = "IfNotPresent"
  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image_pull_policy)
    error_message = "image_pull_policy must be one of: Always, IfNotPresent, Never."
  }
}

variable "termination_grace_period_seconds" {
  description = "Grace period before the pod-node is forcibly terminated."
  type        = number
  default     = 1
}

variable "extra_labels" {
  description = "Extra labels to apply to the Pod and Secret."
  type        = map(string)
  default     = {}
}

variable "extra_annotations" {
  description = "Extra annotations to apply to the Pod."
  type        = map(string)
  default     = {}
}

variable "node_selector" {
  description = "Optional nodeSelector for the pod-node pod."
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Optional tolerations for the pod-node pod."
  type = list(object({
    key      = optional(string)
    operator = optional(string)
    value    = optional(string)
    effect   = optional(string)
  }))
  default = []
}
