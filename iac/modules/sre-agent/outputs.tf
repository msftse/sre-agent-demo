output "endpoint" {
  description = "SRE Agent data-plane endpoint."
  value       = try(azapi_resource.this.output.properties.agentEndpoint, null)
}

output "id" {
  description = "SRE Agent resource ID."
  value       = azapi_resource.this.id
}

output "principal_id" {
  description = "SRE Agent system-assigned managed identity principal ID."
  value       = try(azapi_resource.this.output.identity.principalId, null)
}
