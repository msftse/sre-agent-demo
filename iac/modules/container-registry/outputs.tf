output "id" {
  description = "Container Registry resource ID."
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Container Registry login server."
  value       = azurerm_container_registry.this.login_server
}

output "name" {
  description = "Container Registry name."
  value       = azurerm_container_registry.this.name
}
