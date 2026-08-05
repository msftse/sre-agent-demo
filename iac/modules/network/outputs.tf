output "aks_subnet_id" {
  description = "AKS node subnet resource ID."
  value       = azurerm_subnet.aks.id
}

output "id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "ingress_public_ip_address" {
  description = "Reserved ingress public IPv4 address."
  value       = azurerm_public_ip.ingress.ip_address
}

output "ingress_public_ip_id" {
  description = "Reserved ingress public IP resource ID."
  value       = azurerm_public_ip.ingress.id
}

output "ingress_public_ip_name" {
  description = "Reserved ingress public IP resource name."
  value       = azurerm_public_ip.ingress.name
}
