data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2025-06-01"
  name      = var.storage_account_name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags
  body = {
    kind = "StorageV2"
    sku = {
      name = "Standard_LRS"
    }
    properties = {
      allowBlobPublicAccess        = false
      allowCrossTenantReplication  = false
      allowSharedKeyAccess         = false
      defaultToOAuthAuthentication = true
      isLocalUserEnabled           = false
      isNfsV3Enabled               = false
      isSftpEnabled                = false
      minimumTlsVersion            = "TLS1_2"
      publicNetworkAccess          = "Enabled"
      supportsHttpsTrafficOnly     = true
      encryption = {
        keySource                       = "Microsoft.Storage"
        requireInfrastructureEncryption = true
        services = {
          blob  = { enabled = true, keyType = "Account" }
          file  = { enabled = true, keyType = "Account" }
          queue = { enabled = true, keyType = "Service" }
          table = { enabled = true, keyType = "Service" }
        }
      }
    }
  }
}

resource "azapi_resource" "blob_service" {
  type      = "Microsoft.Storage/storageAccounts/blobServices@2025-06-01"
  name      = "default"
  parent_id = azapi_resource.storage_account.id
  body = {
    properties = {
      deleteRetentionPolicy = {
        enabled = true
        days    = 7
      }
      containerDeleteRetentionPolicy = {
        enabled = true
        days    = 7
      }
    }
  }
}

resource "azapi_resource" "deployment_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01"
  name      = "function-releases"
  parent_id = azapi_resource.blob_service.id
  body = {
    properties = {
      publicAccess = "None"
    }
  }
}

resource "azapi_resource" "table_service" {
  type      = "Microsoft.Storage/storageAccounts/tableServices@2025-06-01"
  name      = "default"
  parent_id = azapi_resource.storage_account.id
  body      = { properties = {} }
}

resource "azapi_resource" "state_table" {
  type      = "Microsoft.Storage/storageAccounts/tableServices/tables@2025-06-01"
  name      = var.storage_table_name
  parent_id = azapi_resource.table_service.id
  body      = { properties = {} }
}

resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV_AZURE_189:Public Key Vault routing is required because this demo intentionally has no Flex VNet integration; data-plane RBAC is UAMI-only.
  #checkov:skip=CKV_AZURE_109:A Key Vault firewall would block the scale-to-zero Flex app without VNet integration; RBAC and purge protection remain enforced.
  #checkov:skip=CKV2_AZURE_32:Private endpoints require VNet integration, explicitly deferred for this public Teams callback demo.
  name                          = var.key_vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_service_plan" "this" {
  #checkov:skip=CKV_AZURE_225:FC1 Flex Consumption is a serverless scale-to-zero plan and does not expose App Service Plan zone balancing.
  #checkov:skip=CKV_AZURE_212:Always-ready instances would defeat the approved scale-to-zero cost posture for this intermittent demo bot.
  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = var.tags
}

resource "azurerm_role_assignment" "runtime_blob" {
  scope                            = azapi_resource.storage_account.id
  role_definition_name             = "Storage Blob Data Owner"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "runtime_account" {
  scope                            = azapi_resource.storage_account.id
  role_definition_name             = "Storage Account Contributor"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "runtime_queue" {
  scope                            = azapi_resource.storage_account.id
  role_definition_name             = "Storage Queue Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "runtime_table" {
  scope                            = azapi_resource.storage_account.id
  role_definition_name             = "Storage Table Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "key_vault_secrets" {
  scope                            = azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "operator_key_vault_secrets" {
  count = var.operator_object_id == null ? 0 : 1

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.operator_object_id
  principal_type       = "User"
}

resource "azurerm_role_assignment" "sre_agent_user" {
  scope                            = var.sre_agent_id
  role_definition_name             = "SRE Agent Standard User"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = var.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id

  storage_container_type            = "blobContainer"
  storage_container_endpoint        = "https://${azapi_resource.storage_account.name}.blob.core.windows.net/${azapi_resource.deployment_container.name}"
  storage_authentication_type       = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.this.id

  runtime_name                                   = "python"
  runtime_version                                = "3.12"
  instance_memory_in_mb                          = 2048
  maximum_instance_count                         = 10
  http_concurrency                               = 20
  https_only                                     = true
  enabled                                        = true
  public_network_access_enabled                  = true
  webdeploy_publish_basic_authentication_enabled = false
  tags                                           = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  app_settings = {
    AzureWebJobsStorage__accountName = azapi_resource.storage_account.name
    AzureWebJobsStorage__clientId    = azurerm_user_assigned_identity.this.client_id
    AzureWebJobsStorage__credential  = "managedidentity"
    AZURE_CLIENT_ID                  = azurerm_user_assigned_identity.this.client_id
    CLIENT_ID                        = var.bot_client_id
    CLIENT_SECRET                    = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=bot-client-secret)"
    TENANT_ID                        = var.bot_tenant_id
    ALLOWED_USER_OBJECT_ID           = var.allowed_user_object_id
    TEAMS_TENANT_ID                  = var.teams_tenant_id
    TEAMS_TEAM_ID                    = var.teams_team_id
    TEAMS_CHANNEL_ID                 = var.teams_channel_id
    STORAGE_ACCOUNT_NAME             = azapi_resource.storage_account.name
    STORAGE_TABLE_NAME               = azapi_resource.state_table.name
    SRE_AGENT_ENDPOINT               = var.sre_agent_endpoint
    MCP_SHARED_KEY                   = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=mcp-shared-key)"
    GITHUB_WEBHOOK_SECRET            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=github-webhook-secret)"
  }

  site_config {
    application_insights_connection_string = var.application_insights_connection_string
    health_check_path                      = "/api/health"
    health_check_eviction_time_in_min      = 2
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    remote_debugging_enabled               = false
    use_32_bit_worker                      = false
    websockets_enabled                     = false
  }

  depends_on = [
    azurerm_role_assignment.runtime_blob,
    azurerm_role_assignment.runtime_account,
    azurerm_role_assignment.runtime_queue,
    azurerm_role_assignment.runtime_table,
    azurerm_role_assignment.key_vault_secrets,
    azurerm_role_assignment.sre_agent_user,
  ]

  lifecycle {
    ignore_changes = [tags["hidden-link: /app-insights-resource-id"]]
  }
}

resource "azapi_update_resource" "key_vault_reference_identity" {
  type        = "Microsoft.Web/sites@2024-11-01"
  resource_id = azurerm_function_app_flex_consumption.this.id
  body = {
    properties = {
      keyVaultReferenceIdentity = azurerm_user_assigned_identity.this.id
    }
  }
}

resource "azurerm_bot_service_azure_bot" "this" {
  name                          = var.bot_name
  resource_group_name           = var.resource_group_name
  location                      = "global"
  microsoft_app_id              = var.bot_client_id
  microsoft_app_type            = "SingleTenant"
  microsoft_app_tenant_id       = var.bot_tenant_id
  sku                           = "F0"
  display_name                  = "Azure SRE Agent"
  endpoint                      = "https://${azurerm_function_app_flex_consumption.this.default_hostname}/api/messages"
  local_authentication_enabled  = true
  public_network_access_enabled = true
  streaming_endpoint_enabled    = false
  tags                          = var.tags
}

resource "azurerm_bot_channel_ms_teams" "this" {
  bot_name               = azurerm_bot_service_azure_bot.this.name
  location               = azurerm_bot_service_azure_bot.this.location
  resource_group_name    = var.resource_group_name
  deployment_environment = "CommercialDeployment"
  calling_enabled        = false
}