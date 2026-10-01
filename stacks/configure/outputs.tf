output "cluster_secret_store_name" {
  value = module.vault_configuration.cluster_secret_store_name
}

output "kv_mount_path" {
  value = module.vault_configuration.kv_mount_path
}
