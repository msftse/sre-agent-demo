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

output "checkout_action_group_id" {
  description = "Action group resource ID used by the checkout incident alert."
  value       = azurerm_monitor_action_group.checkout_incident.id
}

output "checkout_prometheus_rule_group_id" {
  description = "Managed Prometheus checkout alert rule group resource ID."
  value       = azurerm_monitor_alert_prometheus_rule_group.checkout.id
}