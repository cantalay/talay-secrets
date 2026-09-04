variable "kubeconfig_path" {
  type    = string
  default = "../../../talay-cluster/stacks/bootstrap/kubeconfig.yaml"
}

variable "vault_address" {
  description = "Terraform Vault provider endpoint; a local port-forward can be used during bootstrap."
  type        = string
}

variable "vault_cluster_address" {
  description = "Vault address used by External Secrets Operator from inside the cluster."
  type        = string
  default     = "http://vault-active.vault.svc.cluster.local:8200"
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
