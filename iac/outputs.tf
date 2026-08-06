output "resource_group_id" {
  description = "Resource ID of the demo resource group."
  value       = module.resource_group.id
}

output "resource_group_name" {
  description = "Name of the demo resource group."
  value       = module.resource_group.name
}

output "resource_name_suffix" {
  description = "Stable suffix used for globally unique resource names."
  value       = local.suffix
}

output "common_tags" {
  description = "Mandatory and user-supplied tags applied to taggable resources."
  value       = local.common_tags
}

output "acr_id" {
  description = "Azure Container Registry resource ID."
  value       = module.container_registry.id
}

output "acr_login_server" {
  description = "Registry login server passed to scripts/publish-images.sh."
  value       = module.container_registry.login_server
}

output "aks_id" {
  description = "AKS cluster resource ID."
  value       = module.aks.id
}

output "aks_name" {
  description = "AKS cluster name."
  value       = module.aks.name
}

output "aks_node_resource_group" {
  description = "AKS-managed node resource group that must be included in post-apply tag audits."
  value       = module.aks.node_resource_group
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer used for future workload identity federation."
  value       = module.aks.oidc_issuer_url
}

output "github_actions_client_id" {
  description = "Client ID used by GitHub Actions azure/login with OIDC."
  value       = module.identities.github_actions_client_id
}

output "github_actions_oidc_subject" {
  description = "Exact immutable or legacy GitHub Actions OIDC subject trusted by Azure."
  value       = local.github_oidc_subject
}

output "ingress_public_ip_address" {
  description = "Reserved public IP address for the ingress controller."
  value       = module.network.ingress_public_ip_address
}

output "observability" {
  description = "Observability resource endpoints and IDs when enabled."
  value = var.enable_observability ? {
    application_insights_id = module.observability[0].application_insights_id
    grafana_endpoint        = module.observability[0].grafana_endpoint
    log_analytics_id        = module.observability[0].log_analytics_workspace_id
    monitor_workspace_id    = module.observability[0].monitor_workspace_id
    telemetry_client_id     = module.aks_monitoring[0].telemetry_identity_client_id
  } : null
}

output "application_insights_connection_string" {
  description = "Application Insights connection string passed to the backend trace exporter when observability is enabled."
  value       = var.enable_observability ? module.observability[0].application_insights_connection_string : null
  sensitive   = true
}

output "sre_agent" {
  description = "Azure SRE Agent identifiers when enabled."
  value = var.enable_sre_agent ? {
    endpoint     = module.sre_agent[0].endpoint
    id           = module.sre_agent[0].id
    principal_id = module.sre_agent[0].principal_id
  } : null
}
