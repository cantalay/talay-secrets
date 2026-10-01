module "vault" {
  source = "../../modules/vault"

  domain        = var.vault_domain
  storage_class = var.storage_class
  data_size     = var.vault_data_size
  audit_size    = var.vault_audit_size
}

module "external_secrets" {
  source = "../../modules/external-secrets"
}

moved {
  from = helm_release.vault
  to   = module.vault.helm_release.vault
}

moved {
  from = helm_release.external_secrets
  to   = module.external_secrets.helm_release.external_secrets
}
