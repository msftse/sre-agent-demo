resource "azurerm_resource_provider_registration" "this" {
  for_each = var.resource_provider_namespaces

  name = each.value
}

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags

  depends_on = [azurerm_resource_provider_registration.this]
}
