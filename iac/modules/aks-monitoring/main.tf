locals {
  container_insights_streams = [
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
  ]
  prometheus_streams = ["Microsoft-PrometheusMetrics"]
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                = "MSProm-${var.aks_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "Linux"
  tags                = var.tags

  destinations {
    monitor_account {
      monitor_account_id = var.monitor_workspace_id
      name               = "managed-prometheus"
    }
  }

  data_flow {
    streams      = local.prometheus_streams
    destinations = ["managed-prometheus"]
  }

  data_sources {
    prometheus_forwarder {
      name    = "managed-prometheus-forwarder"
      streams = local.prometheus_streams
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "prometheus" {
  name                    = "MSProm-${var.aks_name}"
  target_resource_id      = var.aks_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
}

resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "MSCI-${var.aks_name}-${var.location}"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "Linux"
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "container-insights"
      workspace_resource_id = var.log_analytics_workspace_id
    }
  }

  data_flow {
    streams      = local.container_insights_streams
    destinations = ["container-insights"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = local.container_insights_streams
      extension_json = jsonencode({
        dataCollectionSettings = {
          enableContainerLogV2   = true
          interval               = "5m"
          namespaceFilteringMode = "Include"
          namespaces             = ["northstar"]
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  name                    = "MSCI-${var.aks_name}-${var.location}"
  target_resource_id      = var.aks_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
}

resource "azurerm_monitor_diagnostic_setting" "aks_control_plane" {
  name                           = "aks-control-plane"
  target_resource_id             = var.aks_id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }
}

resource "azurerm_user_assigned_identity" "telemetry" {
  name                = substr("id-telemetry-${var.aks_name}", 0, 128)
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "telemetry" {
  name                      = "northstar-telemetry"
  user_assigned_identity_id = azurerm_user_assigned_identity.telemetry.id
  issuer                    = var.aks_oidc_issuer_url
  subject                   = "system:serviceaccount:${var.workload_namespace}:${var.workload_service_account_name}"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "telemetry_metrics_publisher" {
  scope                            = var.application_insights_id
  role_definition_name             = "Monitoring Metrics Publisher"
  principal_id                     = azurerm_user_assigned_identity.telemetry.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}