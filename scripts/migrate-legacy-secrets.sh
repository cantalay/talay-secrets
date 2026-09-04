#!/usr/bin/env bash
set -euo pipefail
umask 077

destination_mount=${DEST_KV_MOUNT:-kv}
migration_apply=${MIGRATION_APPLY:-false}
temporary_files=()
kubectl_args=()

if [[ -n "${SOURCE_KUBECONFIG:-}" ]]; then
  kubectl_args+=(--kubeconfig "$SOURCE_KUBECONFIG")
fi
if [[ -n "${SOURCE_CONTEXT:-}" ]]; then
  kubectl_args+=(--context "$SOURCE_CONTEXT")
fi

cleanup() {
  local temporary_file
  for temporary_file in "${temporary_files[@]:-}"; do
    [[ -f "$temporary_file" ]] || continue
    if command -v shred >/dev/null 2>&1; then
      shred --remove "$temporary_file"
    else
      : >"$temporary_file"
      rm -f "$temporary_file"
    fi
  done
}
trap cleanup EXIT INT TERM

kctl() {
  kubectl "${kubectl_args[@]}" "$@"
}

for command_name in kubectl jq base64 gzip; do
  command -v "$command_name" >/dev/null || {
    printf 'Required command is missing: %s\n' "$command_name" >&2
    exit 1
  }
done

case "$migration_apply" in
  true | false) ;;
  *)
    printf 'MIGRATION_APPLY must be true or false.\n' >&2
    exit 1
    ;;
esac

if [[ "$migration_apply" == true ]]; then
  : "${DEST_VAULT_ADDR:?Set DEST_VAULT_ADDR to the new Vault URL}"
  : "${DEST_VAULT_TOKEN:?Set DEST_VAULT_TOKEN in the shell; never place it in a file}"
  command -v vault >/dev/null || {
    printf 'Required command is missing: vault\n' >&2
    exit 1
  }
  VAULT_ADDR="$DEST_VAULT_ADDR" VAULT_TOKEN="$DEST_VAULT_TOKEN" vault status >/dev/null
  VAULT_ADDR="$DEST_VAULT_ADDR" VAULT_TOKEN="$DEST_VAULT_TOKEN" vault secrets list -format=json \
    | jq -e --arg mount "${destination_mount}/" 'has($mount)' >/dev/null || {
        printf 'Destination KV mount does not exist: %s/\n' "$destination_mount" >&2
        exit 1
      }
fi

state_payload() {
  local state_secret=$1
  kctl -n terraform-states get secret "$state_secret" -o jsonpath='{.data.tfstate}' \
    | base64 --decode \
    | gzip --decompress
}

kubernetes_secret_data() {
  local namespace=$1
  local secret_name=$2
  kctl -n "$namespace" get secret "$secret_name" -o json \
    | jq -c '.data | with_entries(.value |= @base64d)'
}

put_secret() {
  local path=$1
  local json_data=$2
  local key_names
  local temporary_file

  key_names=$(jq -r 'keys | join(",")' <<<"$json_data")
  printf '%-32s keys=%s' "$path" "$key_names"

  if [[ "$migration_apply" != true ]]; then
    printf ' [dry-run]\n'
    return
  fi

  temporary_file=$(mktemp)
  temporary_files+=("$temporary_file")
  chmod 600 "$temporary_file"
  jq -e '
    if type == "object" and length > 0
    then .
    else error("secret payload must be a non-empty object")
    end
  ' <<<"$json_data" >"$temporary_file"

  VAULT_ADDR="$DEST_VAULT_ADDR" VAULT_TOKEN="$DEST_VAULT_TOKEN" \
    vault kv put -mount="$destination_mount" "$path" @"$temporary_file" >/dev/null

  printf ' [written]\n'
  if command -v shred >/dev/null 2>&1; then
    shred --remove "$temporary_file"
  else
    : >"$temporary_file"
    rm -f "$temporary_file"
  fi
  temporary_files=("${temporary_files[@]/$temporary_file}")
}

printf 'Preserving legacy Vault paths recovered from Terraform state:\n'
for state_secret in tfstate-default-app-state tfstate-default-infra-state; do
  while IFS= read -r record; do
    put_secret "$(jq -r '.path' <<<"$record")" "$(jq -c '.data' <<<"$record")"
  done < <(
    state_payload "$state_secret" \
      | jq -c '
          .resources[]?
          | select(.mode == "data" and .type == "vault_kv_secret_v2")
          | .instances[]?.attributes
          | {path: .name, data: .data}
        '
  )
done

printf '\nWriting authoritative current workload secrets and normalized platform paths:\n'

postgresql_json=$(kubernetes_secret_data database postgresql \
  | jq -c '{"postgres-password": .["postgres-password"], password: .password}')
put_secret platform/postgresql "$postgresql_json"
unset postgresql_json

redis_json=$(kubernetes_secret_data redis redis \
  | jq -c '{"redis-password": .["redis-password"]}')
put_secret platform/redis "$redis_json"
unset redis_json

keycloak_json=$(kubernetes_secret_data keycloak keycloak-secrets \
  | jq -c '{username: .KEYCLOAK_ADMIN_USER, password: .KEYCLOAK_ADMIN_PASSWORD}')
put_secret platform/keycloak "$keycloak_json"
unset keycloak_json

grafana_json=$(kubernetes_secret_data monitoring kube-prometheus-stack-grafana \
  | jq -c '{"admin-user": .["admin-user"], "admin-password": .["admin-password"]}')
put_secret platform/grafana "$grafana_json"
unset grafana_json

alertmanager_json=$(kubernetes_secret_data monitoring alertmanager-kube-prometheus-stack-alertmanager \
  | jq -c '{config: .["alertmanager.yaml"]}')
put_secret platform/alertmanager "$alertmanager_json"
unset alertmanager_json

todogi_json=$(kubernetes_secret_data todogi-be todogi-backend-secrets)
put_secret todogi/backend "$todogi_json"
unset todogi_json

todogi_keycloak_json=$(kubernetes_secret_data gateway auth-gateway-secrets)
put_secret keycloak/todogi "$todogi_keycloak_json"
unset todogi_keycloak_json

if [[ "$migration_apply" == true ]]; then
  printf '\nMigration writes completed. Re-run with MIGRATION_APPLY=false to compare path/key inventory.\n'
else
  printf '\nDry-run only. Review the inventory, then set MIGRATION_APPLY=true.\n'
fi
