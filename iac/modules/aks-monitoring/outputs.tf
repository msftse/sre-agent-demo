output "container_insights_data_collection_rule_id" {
  description = "Container Insights data collection rule resource ID."
  value       = azurerm_monitor_data_collection_rule.container_insights.id
}

output "prometheus_data_collection_rule_id" {
  description = "Managed Prometheus data collection rule resource ID."
  value       = azurerm_monitor_data_collection_rule.prometheus.id
}

output "telemetry_identity_client_id" {
  description = "Client ID annotated on the Kubernetes service account for Application Insights ingestion."
  value       = azurerm_user_assigned_identity.telemetry.client_id
}