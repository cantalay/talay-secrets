variable "kubeconfig_path" {
  type    = string
  default = "../../../talay-cluster/stacks/bootstrap/kubeconfig.yaml"
}

variable "vault_address" {
  type = string
}

variable "kubernetes_host" {
  description = "Vault pod'un erişebildiği Kubernetes API URL'i. Cluster içi varsayılan kullanılır."
  type        = string
  default     = "https://kubernetes.default.svc:443"
}

variable "kv_mount_path" {
  type    = string
  default = "kv"
}
