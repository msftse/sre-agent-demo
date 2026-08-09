output "endpoint" {
  description = "SRE Agent data-plane endpoint."
  value       = try(azapi_resource.this.output.properties.agentEndpoint, null)
}

output "id" {
  description = "SRE Agent resource ID."
  value       = azapi_resource.this.id
}

output "principal_id" {
  description = "SRE Agent user-assigned managed identity principal ID used for resource access."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "identity_id" {
  description = "SRE Agent user-assigned managed identity resource ID."
  value       = azurerm_user_assigned_identity.this.id
}

output "monitoring_contributor_role_assignment_id" {
  description = "Subscription-scoped Monitoring Contributor assignment used by Azure Monitor incident scanning."
  value       = azurerm_role_assignment.monitoring_contributor.id
}
