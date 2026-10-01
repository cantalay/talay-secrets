resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "2.10.0"

  atomic  = true
  wait    = true
  timeout = 600

  values = [yamlencode({
    global            = { repository = "oci.external-secrets.io/external-secrets/external-secrets" }
    installCRDs       = true
    priorityClassName = "talay-platform-critical"
    serviceMonitor    = { enabled = false }
    webhook           = { priorityClassName = "talay-platform-critical" }
    certController    = { priorityClassName = "talay-platform-critical" }
    resources = {
      requests = { cpu = "20m", memory = "64Mi" }
      limits   = { memory = "192Mi" }
    }
  })]
}
