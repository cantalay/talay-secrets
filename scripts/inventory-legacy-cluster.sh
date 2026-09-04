#!/usr/bin/env bash
set -euo pipefail

kubectl_args=()
if [[ -n "${SOURCE_KUBECONFIG:-}" ]]; then
  kubectl_args+=(--kubeconfig "$SOURCE_KUBECONFIG")
fi
if [[ -n "${SOURCE_CONTEXT:-}" ]]; then
  kubectl_args+=(--context "$SOURCE_CONTEXT")
fi

kctl() {
  kubectl "${kubectl_args[@]}" "$@"
}

for command_name in kubectl jq base64 gzip; do
  command -v "$command_name" >/dev/null || {
    printf 'Required command is missing: %s\n' "$command_name" >&2
    exit 1
  }
done

printf 'Context: '
kctl config current-context
kctl -n vault exec vault-0 -- vault status -format=json 2>/dev/null \
  | jq '{initialized,sealed,storage_type,version,ha_enabled}' || true

printf '\nVault KV references retained in Terraform state (values hidden):\n'
for state_secret in \
  tfstate-default-app-state \
  tfstate-default-base-state \
  tfstate-default-infra-state \
  tfstate-default-ingress-state; do
  kctl -n terraform-states get secret "$state_secret" -o jsonpath='{.data.tfstate}' \
    | base64 --decode \
    | gzip --decompress \
    | jq -r --arg state "$state_secret" '
        .resources[]?
        | select(.mode == "data" and .type == "vault_kv_secret_v2")
        | .instances[]?.attributes
        | [$state, .mount, .name, ((.data // {}) | keys | join(","))]
        | @tsv
      '
done

printf '\nKubernetes application/config Secrets (values hidden):\n'
kctl get secret -A -o json \
  | jq -r '
      .items[]
      | select(
          .type != "helm.sh/release.v1"
          and .type != "kubernetes.io/tls"
          and .type != "kubernetes.io/service-account-token"
          and .type != "kubernetes.io/dockerconfigjson"
        )
      | [.metadata.namespace, .metadata.name, ((.data // {}) | keys | join(","))]
      | @tsv
    ' \
  | sort

printf '\nVault Agent injector annotations:\n'
kctl get deployment,statefulset,daemonset,job,cronjob -A -o json \
  | jq -r '
      .items[]
      | select(
          (.spec.template.metadata.annotations // {})
          | to_entries
          | any(.key | startswith("vault.hashicorp.com/"))
        )
      | [.kind, .metadata.namespace, .metadata.name]
      | @tsv
    '
