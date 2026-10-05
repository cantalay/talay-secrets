resource "vault_mount" "platform" {
  path        = var.kv_mount_path
  type        = "kv-v2"
  description = "Talay platform and application secrets"
  options     = { version = "2" }
}

resource "vault_audit" "file" {
  type    = "file"
  options = { file_path = "/vault/audit/audit.log", log_raw = "false" }
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
  name   = "external-secrets-read"
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

# Host-level nightly backup (talay-backup.service on the node) takes raft snapshots only.
resource "vault_policy" "raft_snapshot" {
  name   = "raft-snapshot"
  policy = <<-EOT
    path "sys/storage/raft/snapshot" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "vault_backup" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "vault-backup"
  bound_service_account_names      = ["vault-backup"]
  bound_service_account_namespaces = ["vault"]
  token_policies                   = [vault_policy.raft_snapshot.name]
  token_ttl                        = 600
  token_max_ttl                    = 600
}

resource "vault_policy" "platform_admin" {
  name   = "platform-admin"
  policy = <<-EOT
    path "*" {
      capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
    }
  EOT
}

resource "vault_jwt_auth_backend" "oidc" {
  type        = "oidc"
  path        = "oidc"
  description = "Keycloak OIDC for Talay platform administrators"

  oidc_discovery_url = var.oidc_discovery_url
  oidc_client_id     = var.oidc_client_id
  default_role       = "platform-admin"

  oidc_client_secret_wo         = var.oidc_client_secret
  oidc_client_secret_wo_version = var.oidc_client_secret_version

  tune { listing_visibility = "unauth" }
}

resource "vault_jwt_auth_backend_role" "platform_admin" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "platform-admin"
  role_type       = "oidc"
  bound_audiences = [var.oidc_client_id]
  bound_claims    = { groups = "talay-platform-admins" }
  user_claim      = "preferred_username"
  groups_claim    = "groups"
  oidc_scopes     = ["profile", "email"]
  allowed_redirect_uris = [
    "${trimsuffix(var.vault_public_url, "/")}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]
  token_policies = [vault_policy.platform_admin.name]
  token_ttl      = 3600
  token_max_ttl  = 28800
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
