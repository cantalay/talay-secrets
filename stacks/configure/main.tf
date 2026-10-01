module "vault_configuration" {
  source = "../../modules/vault-configuration"

  vault_cluster_address      = var.vault_cluster_address
  kubernetes_host            = var.kubernetes_host
  vault_public_url           = var.vault_public_url
  oidc_discovery_url         = var.oidc_discovery_url
  oidc_client_id             = var.oidc_client_id
  oidc_client_secret         = var.oidc_client_secret
  oidc_client_secret_version = var.oidc_client_secret_version
  kv_mount_path              = var.kv_mount_path
}

moved {
  from = vault_mount.platform
  to   = module.vault_configuration.vault_mount.platform
}

moved {
  from = vault_audit.file
  to   = module.vault_configuration.vault_audit.file
}

moved {
  from = vault_auth_backend.kubernetes
  to   = module.vault_configuration.vault_auth_backend.kubernetes
}

moved {
  from = vault_kubernetes_auth_backend_config.cluster
  to   = module.vault_configuration.vault_kubernetes_auth_backend_config.cluster
}

moved {
  from = vault_policy.external_secrets
  to   = module.vault_configuration.vault_policy.external_secrets
}

moved {
  from = vault_kubernetes_auth_backend_role.external_secrets
  to   = module.vault_configuration.vault_kubernetes_auth_backend_role.external_secrets
}

moved {
  from = vault_policy.platform_admin
  to   = module.vault_configuration.vault_policy.platform_admin
}

moved {
  from = vault_jwt_auth_backend.oidc
  to   = module.vault_configuration.vault_jwt_auth_backend.oidc
}

moved {
  from = vault_jwt_auth_backend_role.platform_admin
  to   = module.vault_configuration.vault_jwt_auth_backend_role.platform_admin
}

moved {
  from = helm_release.cluster_secret_store
  to   = module.vault_configuration.helm_release.cluster_secret_store
}
