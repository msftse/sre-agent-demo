resource "azurerm_log_analytics_workspace" "this" {
  name                         = var.log_analytics_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = "PerGB2018"
  retention_in_days            = var.retention_in_days
  internet_ingestion_enabled   = true
  internet_query_enabled       = true
  local_authentication_enabled = false
  tags                         = var.tags
}

resource "azurerm_application_insights" "this" {
  name                         = var.application_insights_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  workspace_id                 = azurerm_log_analytics_workspace.this.id
  application_type             = "web"
  retention_in_days            = var.retention_in_days
  internet_ingestion_enabled   = true
  internet_query_enabled       = true
  local_authentication_enabled = false
  sampling_percentage          = 100
  tags                         = var.tags
}

resource "azurerm_monitor_workspace" "this" {
  name                          = var.monitor_workspace_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_dashboard_grafana" "this" {
  name                              = var.grafana_name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  grafana_major_version             = var.grafana_major_version
  sku                               = "Standard"
  api_key_enabled                   = false
  deterministic_outbound_ip_enabled = false
  public_network_access_enabled     = true
  zone_redundancy_enabled           = false
  tags                              = var.tags

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.this.id
  }
}

resource "azurerm_role_assignment" "grafana_monitor_data_reader" {
  scope                            = azurerm_monitor_workspace.this.id
  role_definition_name             = "Monitoring Data Reader"
  principal_id                     = azurerm_dashboard_grafana.this.identity[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
