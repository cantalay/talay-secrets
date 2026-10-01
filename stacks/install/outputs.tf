output "vault_address" {
  value = module.vault.address
}

output "vault_initialize_command" {
  value = "kubectl -n vault exec vault-0 -- vault operator init"
}
