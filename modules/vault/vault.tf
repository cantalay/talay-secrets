locals {
  vault_config = <<-EOT
    ui = true

    listener "tcp" {
      tls_disable     = 1
      address         = "[::]:8200"
      cluster_address = "[::]:8201"

      telemetry {
        unauthenticated_metrics_access = "true"
      }
    }

    storage "raft" {
      path = "/vault/data"
    }

    service_registration "kubernetes" {}

    telemetry {
      prometheus_retention_time = "30s"
      disable_hostname          = true
    }
  EOT
}

resource "helm_release" "vault" {
  name       = "vault"
  namespace  = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.34.1"

  atomic  = false
  wait    = false
  timeout = 600

  values = [yamlencode({
    injector = { enabled = false }
    server = {
      priorityClassName = "talay-platform-critical"
      logFormat         = "json"
      authDelegator     = { enabled = true }
      dataStorage = {
        enabled      = true
        size         = var.data_size
        storageClass = var.storage_class
      }
      auditStorage = {
        enabled      = true
        size         = var.audit_size
        storageClass = var.storage_class
      }
      persistentVolumeClaimRetentionPolicy = {
        whenDeleted = "Retain"
        whenScaled  = "Retain"
      }
      standalone = { enabled = false }
      ha = {
        enabled  = true
        replicas = 1
        raft = {
          enabled   = true
          setNodeId = true
          config    = local.vault_config
        }
      }
      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        activeService    = true
        annotations      = { "cert-manager.io/cluster-issuer" = "letsencrypt" }
        hosts            = [{ host = var.domain, paths = ["/"] }]
        tls              = [{ secretName = "vault-tls", hosts = [var.domain] }]
      }
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { memory = "512Mi" }
      }
    }
    ui = { enabled = true }
    serverTelemetry = { serviceMonitor = { enabled = false } }
  })]
}
