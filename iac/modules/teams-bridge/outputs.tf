output "function_app_id" {
  description = "Teams bridge Function App resource ID."
  value       = azurerm_function_app_flex_consumption.this.id
}

output "function_app_name" {
  description = "Teams bridge Function App name."
  value       = azurerm_function_app_flex_consumption.this.name
}

output "messaging_endpoint" {
  description = "Bot Connector messaging endpoint."
  value       = azurerm_bot_service_azure_bot.this.endpoint
}

output "mcp_endpoint" {
  description = "Streamable HTTP MCP endpoint for outbound Teams notifications."
  value       = "https://${azurerm_function_app_flex_consumption.this.default_hostname}/api/mcp"
}

output "identity_principal_id" {
  description = "Teams bridge managed identity principal ID."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "key_vault_name" {
  description = "Key Vault name where interactive credentials must be stored."
  value       = azurerm_key_vault.this.name
}