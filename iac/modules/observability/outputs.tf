output "application_insights_connection_string" {
  description = "Application Insights connection string used by the future OpenTelemetry exporter."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "application_insights_id" {
  description = "Application Insights resource ID."
  value       = azurerm_application_insights.this.id
}

output "grafana_endpoint" {
  description = "Azure Managed Grafana endpoint."
  value       = azurerm_dashboard_grafana.this.endpoint
}

output "grafana_id" {
  description = "Azure Managed Grafana resource ID."
  value       = azurerm_dashboard_grafana.this.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.this.id
}

output "monitor_workspace_id" {
  description = "Azure Monitor workspace resource ID."
  value       = azurerm_monitor_workspace.this.id
}
