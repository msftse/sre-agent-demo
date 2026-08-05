output "id" {
  description = "Resource group ID."
  value       = azurerm_resource_group.this.id
}

output "location" {
  description = "Resource group Azure region."
  value       = azurerm_resource_group.this.location
}

output "name" {
  description = "Resource group name."
  value       = azurerm_resource_group.this.name
}
