output "github_actions_client_id" {
  description = "Client ID used by GitHub Actions OIDC login."
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "github_actions_id" {
  description = "GitHub Actions managed identity resource ID."
  value       = azurerm_user_assigned_identity.github_actions.id
}

output "github_actions_principal_id" {
  description = "GitHub Actions managed identity principal ID."
  value       = azurerm_user_assigned_identity.github_actions.principal_id
}
