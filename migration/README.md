# Legacy Vault migration

## Current finding

The legacy Vault is initialized and uses integrated Raft, but it is sealed. No unseal key or root token was found in Kubernetes Secrets, environment variables or shell history. Vault cannot expose mounts, policies or live KV data until an authorized operator supplies the unseal material.

Five encrypted recovery artifacts were captured outside every Git repository:

- `legacy-vault-raft-sealed-2026-09-04.tar.gz.gpg`: the complete sealed `/vault/data` directory.
- `legacy-terraform-states-2026-09-04.json.gpg`: the four Kubernetes-backend Terraform state Secrets.
- `legacy-postgresql-all-2026-09-04.sql.gz.gpg`: all PostgreSQL databases, roles and schemas without role-password hashes.
- `legacy-redis-2026-09-04.rdb.gpg`: a point-in-time Redis RDB stream.
- `legacy-kubernetes-secrets-2026-09-04.json.gpg`: all 61 legacy Kubernetes Secret objects, including metadata and encrypted data fields.

They are stored under `/home/cant/Documents/Codex/2026-09-03/vault-migration-private` with mode `0600`. Their symmetric encryption password is stored in the OS keyring under attributes `service=talay-vault-migration` and `backup=legacy-2026-09-04`; it is not stored in Git.

An exact Raft restore carries the source Vault barrier and therefore still requires the original unseal keys. For a fresh Vault with new unseal keys, use the logical migration below. It rebuilds the platform auth/policy configuration through Terraform and copies application secret values into the new KV v2 mount.

## Logical migration

Prerequisites:

- Either a working source-cluster `kubectl` context or both encrypted local backup bundles.
- `jq`, `gzip`, `base64`, and a local `vault` CLI.
- Initialized and unsealed destination Vault.
- `talay-secrets/stacks/configure` applied so the destination `kv/` mount exists.
- A short-lived destination token allowed to write the listed migration paths.

Inventory without values:

```bash
./scripts/inventory-legacy-cluster.sh
```

Dry-run; this prints paths and key names only:

```bash
./scripts/migrate-legacy-secrets.sh
```

After the legacy cluster is removed, use the encrypted local copies instead. The
passphrase is read from the OS keyring and no plaintext bundle is written:

```bash
MIGRATION_SOURCE=encrypted-backup ./scripts/migrate-legacy-secrets.sh
```

Apply after reviewing the dry-run:

```bash
export DEST_VAULT_ADDR=https://vault.cantalay.com
export DEST_VAULT_TOKEN='set-in-shell-only'
MIGRATION_SOURCE=encrypted-backup MIGRATION_APPLY=true ./scripts/migrate-legacy-secrets.sh
```

The script does not export plaintext bundles. It reads each source value into process memory, writes a mode `0600` temporary file only for the duration of one `vault kv put`, then securely removes it. It preserves the four legacy Vault paths visible in Terraform state and also writes normalized `platform/*` paths required by the new architecture.

After migration, compare destination path/key inventory with [`legacy-inventory.yaml`](legacy-inventory.yaml), start External Secrets Operator reconciliation, and validate workloads before revoking the migration token.

Database contents are a separate migration. In particular, the legacy PostgreSQL instance uses database/user `keycloak`; the new defaults use `talay`. Do not cut Keycloak or Todogi over until PostgreSQL roles, databases, schemas and application data are migrated and the new variables are aligned.
