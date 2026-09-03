variable "kubeconfig_path" {
  type    = string
  default = "../../../talay-cluster/stacks/bootstrap/kubeconfig.yaml"
}

variable "vault_domain" {
  type = string
}

variable "storage_class" {
  type    = string
  default = "local-path"
}

variable "vault_data_size" {
  type    = string
  default = "10Gi"
}

variable "vault_audit_size" {
  type    = string
  default = "5Gi"
}
