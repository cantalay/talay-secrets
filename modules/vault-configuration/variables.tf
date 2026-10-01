variable "vault_cluster_address" { type = string }
variable "kubernetes_host" { type = string }
variable "vault_public_url" { type = string }
variable "oidc_discovery_url" { type = string }
variable "oidc_client_id" { type = string }
variable "oidc_client_secret" {
  type      = string
  sensitive = true
  ephemeral = true
}
variable "oidc_client_secret_version" { type = number }
variable "kv_mount_path" { type = string }
