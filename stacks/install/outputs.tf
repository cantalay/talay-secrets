output "vault_address" {
  value = "https://${var.vault_domain}"
}

output "vault_initialize_command" {
  value = "kubectl -n vault exec vault-0 -- vault operator init"
}
