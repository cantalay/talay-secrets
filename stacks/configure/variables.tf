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

variable "vault_public_url" {
  description = "Public Vault URL used for the browser OIDC callback."
  type        = string
  default     = "https://vault.cantalay.com"
}

variable "oidc_discovery_url" {
  description = "Keycloak realm issuer/discovery base URL."
  type        = string
  default     = "https://auth.cantalay.com/realms/monitoring"
}

variable "oidc_client_id" {
  type    = string
  default = "talay-vault"
}

variable "oidc_client_secret" {
  description = "Vault OIDC client secret. Supply from Vault through TF_VAR_oidc_client_secret."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "oidc_client_secret_version" {
  description = "Increment to rotate the write-only Vault OIDC client secret."
  type        = number
  default     = 1
}

variable "kv_mount_path" {
  type    = string
  default = "kv"
}
