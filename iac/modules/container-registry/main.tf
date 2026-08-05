resource "azurerm_container_registry" "this" {
  #checkov:skip=CKV_AZURE_237:Dedicated data endpoints require Premium; this ephemeral single-region demo uses Standard.
  #checkov:skip=CKV_AZURE_233:Zone redundancy requires Premium and is outside the single-region demo availability profile.
  #checkov:skip=CKV_AZURE_167:Untagged manifest retention requires Premium; immutable SHA tags and explicit teardown bound demo storage.
  #checkov:skip=CKV_AZURE_164:ACR content trust is not used; Stage 9 produces SBOMs and performs authenticated image scanning before deployment.
  #checkov:skip=CKV_AZURE_165:Geo-replication conflicts with the confirmed single-region demo scope.
  #checkov:skip=CKV_AZURE_166:Quarantine requires a promotion service not present in this demo; Stage 9 scan gates deployment instead.
  #checkov:skip=CKV_AZURE_139:Public registry access is required for local Docker and GitHub-hosted runner pushes; admin credentials and anonymous pull remain disabled.

  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  data_endpoint_enabled         = false
  export_policy_enabled         = var.sku == "Premium" ? false : null
  public_network_access_enabled = true
  quarantine_policy_enabled     = false
  role_assignment_mode          = "LegacyRegistryPermissions"
  zone_redundancy_enabled       = false
  tags                          = var.tags
}
