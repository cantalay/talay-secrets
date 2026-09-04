# talay-secrets

Secrets katmanının yaşam döngüsü iki state'e ayrılır:

- `stacks/install`: Vault ve External Secrets Operator'ı Helm ile kurar.
- `stacks/configure`: Vault KV v2 mount, audit, Kubernetes auth/policy/role ve cluster-wide `ClusterSecretStore` oluşturur.

Vault chart kurulumu bilinçli olarak `wait = false` çalışır; yeni Vault initialize ve unseal edilmeden Ready olmaz. İlk kurulumda recovery/unseal materyalini güvenli, cluster dışı bir parola yöneticisi veya KMS'e alın. Root token'ı Git'e, tfvars'a veya Terraform state'e koymayın; yalnızca işlem sırasında `VAULT_TOKEN` ortam değişkeniyle verin.

Tek node için bir replikalı integrated Raft seçildi. Çok node'a geçerken replica, anti-affinity, auto-unseal ve raft snapshot/off-site backup birlikte ele alınmalıdır.

## Legacy migration

Mevcut cluster'daki Vault/Terraform/Kubernetes secret envanteri ve güvenli aktarım akışı [`migration/README.md`](migration/README.md) altında tutulur. Aktarım aracı varsayılan olarak dry-run çalışır; secret değerlerini stdout'a yazmaz ve hedef Vault'a ancak `MIGRATION_APPLY=true` verildiğinde yazar.
