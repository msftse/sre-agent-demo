resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azapi_resource" "this" {
  type      = "Microsoft.App/agents@2026-01-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  schema_validation_enabled = false
  response_export_values = [
    "identity.principalId",
    "properties.agentEndpoint",
  ]

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  body = {
    properties = merge({
      actionConfiguration = {
        accessLevel = "Low"
        identity    = azurerm_user_assigned_identity.this.id
        mode        = "Review"
      }
      incidentManagementConfiguration = {
        connectionName = "azmonitor"
        type           = "AzMonitor"
      }
      knowledgeGraphConfiguration = {
        identity         = azurerm_user_assigned_identity.this.id
        managedResources = var.managed_resource_ids
      }
      upgradeChannel = var.upgrade_channel
      }, var.application_insights_app_id != null && var.application_insights_connection_string != null ? {
      logConfiguration = {
        applicationInsightsConfiguration = {
          appId            = var.application_insights_app_id
          connectionString = var.application_insights_connection_string
        }
      }
    } : {})
  }
}

resource "azurerm_role_assignment" "monitoring_contributor" {
  scope                            = "/subscriptions/${var.subscription_id}"
  role_definition_name             = "Monitoring Contributor"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "resource_reader" {
  scope                            = var.resource_group_id
  role_definition_name             = "Reader"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "monitoring_reader" {
  scope                            = var.resource_group_id
  role_definition_name             = "Monitoring Reader"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "log_analytics_reader" {
  scope                            = var.resource_group_id
  role_definition_name             = "Log Analytics Reader"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                            = var.aks_id
  role_definition_name             = "Azure Kubernetes Service Cluster User Role"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_rbac_reader" {
  scope                            = var.aks_id
  role_definition_name             = "Azure Kubernetes Service RBAC Reader"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "operator_administrator" {
  count = var.operator_object_id == null ? 0 : 1

  scope                = azapi_resource.this.id
  role_definition_name = "SRE Agent Administrator"
  principal_id         = var.operator_object_id
  principal_type       = "User"
}
