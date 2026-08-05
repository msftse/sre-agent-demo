resource "azapi_resource" "this" {
  type      = "Microsoft.App/agents@2026-01-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  schema_validation_enabled = false
  response_export_values = [
    "identity.principalId",
    "properties.agentEndpoint",
  ]

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      actionConfiguration = {
        accessLevel = "Low"
        mode        = "Review"
      }
      incidentManagementConfiguration = {
        type = "None"
      }
      knowledgeGraphConfiguration = {
        managedResources = var.managed_resource_ids
      }
      upgradeChannel = var.upgrade_channel
    }
  }
}
