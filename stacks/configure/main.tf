resource "vault_mount" "platform" {
  path        = var.kv_mount_path
  type        = "kv-v2"
  description = "Talay platform and application secrets"

  options = {
    version = "2"
  }
}

resource "vault_audit" "file" {
  type = "file"

  options = {
    file_path = "/vault/audit/audit.log"
    log_raw   = "false"
  }
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "cluster" {
  backend              = vault_auth_backend.kubernetes.path
  kubernetes_host      = var.kubernetes_host
  disable_local_ca_jwt = false
}

resource "vault_policy" "external_secrets" {
  name = "external-secrets-read"

  policy = <<-EOT
    path "${vault_mount.platform.path}/data/*" {
      capabilities = ["read"]
    }

    path "${vault_mount.platform.path}/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "external-secrets"
  bound_service_account_names      = ["vault-auth"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.external_secrets.name]
  token_ttl                        = 3600
  token_max_ttl                    = 7200
}

resource "helm_release" "cluster_secret_store" {
  name      = "vault-cluster-secret-store"
  namespace = "external-secrets"
  chart     = "${path.module}/charts/cluster-secret-store"

  atomic  = true
  wait    = true
  timeout = 300

  values = [yamlencode({
    vault = {
      server    = var.vault_cluster_address
      path      = vault_mount.platform.path
      authMount = vault_auth_backend.kubernetes.path
      role      = vault_kubernetes_auth_backend_role.external_secrets.role_name
    }
  })]
}
