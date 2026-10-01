output "cluster_secret_store_name" { value = "vault" }
output "kv_mount_path" { value = vault_mount.platform.path }
