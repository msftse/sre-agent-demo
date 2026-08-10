resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

data "azuread_client_config" "current" {}

locals {
  suffix                  = coalesce(var.name_suffix, random_string.suffix.result)
  compact_project         = replace(var.project_name, "-", "")
  github_repository_parts = split("/", var.github_repository)
  github_oidc_repository = (
    var.github_repository_owner_id != null && var.github_repository_id != null
    ? "${local.github_repository_parts[0]}@${var.github_repository_owner_id}/${local.github_repository_parts[1]}@${var.github_repository_id}"
    : var.github_repository
  )
  github_oidc_subject = "repo:${local.github_oidc_repository}:environment:${var.github_environment}"
  resource_group_name = "rg-${var.project_name}-${var.environment}-${local.suffix}"
  vnet_name           = "vnet-${var.project_name}-${var.environment}-${local.suffix}"
  aks_name            = "aks-${var.project_name}-${var.environment}-${local.suffix}"
  acr_name            = substr("acr${local.compact_project}${var.environment}${local.suffix}", 0, 50)
  github_identity_name = substr(
    "id-github-${var.project_name}-${var.environment}-${local.suffix}",
    0,
    128,
  )
  log_analytics_name          = "log-${var.project_name}-${var.environment}-${local.suffix}"
  app_insights_name           = "appi-${var.project_name}-${var.environment}-${local.suffix}"
  monitor_name                = "amw-${var.project_name}-${var.environment}-${local.suffix}"
  grafana_name                = "amg-${substr(local.compact_project, 0, 6)}-${var.environment}-${local.suffix}"
  sre_agent_name              = "sre-${var.project_name}-${var.environment}-${local.suffix}"
  teams_bridge_name           = "func-tm-${substr(local.compact_project, 0, 8)}-${var.environment}-${local.suffix}"
  teams_bridge_storage_name   = "sttm${substr(local.compact_project, 0, 8)}${var.environment}${local.suffix}"
  teams_bridge_key_vault_name = "kv-tm-${substr(local.compact_project, 0, 8)}-${local.suffix}"
  common_tags = merge(var.tags, {
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Project         = var.project_name
    SecurityControl = "Ignore"
  })
}

resource "azuread_application" "teams_bot" {
  count = var.enable_teams_bridge ? 1 : 0

  display_name            = "Azure SRE Agent ${var.environment} ${local.suffix}"
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = true
  owners                  = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "teams_bot" {
  count = var.enable_teams_bridge ? 1 : 0

  client_id = azuread_application.teams_bot[0].client_id
  owners    = [data.azuread_client_config.current.object_id]
}

module "resource_group" {
  source = "./modules/resource-group"

  location = var.location
  name     = local.resource_group_name
  tags     = local.common_tags
}

module "network" {
  source = "./modules/network"

  aks_subnet_address_prefixes = var.aks_subnet_address_prefixes
  location                    = module.resource_group.location
  name                        = local.vnet_name
  public_ip_name              = "pip-${var.project_name}-${var.environment}-${local.suffix}"
  resource_group_name         = module.resource_group.name
  tags                        = local.common_tags
  vnet_address_space          = var.vnet_address_space
}

module "container_registry" {
  source = "./modules/container-registry"

  location            = module.resource_group.location
  name                = local.acr_name
  resource_group_name = module.resource_group.name
  sku                 = var.acr_sku
  tags                = local.common_tags
}

module "aks" {
  source = "./modules/aks"

  dns_service_ip             = var.aks_dns_service_ip
  kubernetes_version         = null
  location                   = module.resource_group.location
  log_analytics_workspace_id = var.enable_observability ? module.observability[0].log_analytics_workspace_id : null
  managed_prometheus_enabled = var.enable_observability
  name                       = local.aks_name
  node_count                 = var.aks_node_count
  node_vm_size               = var.aks_node_vm_size
  pod_cidr                   = var.aks_pod_cidr
  resource_group_name        = module.resource_group.name
  service_cidr               = var.aks_service_cidr
  sku_tier                   = var.aks_sku_tier
  subnet_id                  = module.network.aks_subnet_id
  tags                       = local.common_tags
  tenant_id                  = var.tenant_id
}

module "identities" {
  source = "./modules/identities"

  acr_id                   = module.container_registry.id
  aks_id                   = module.aks.id
  aks_kubelet_principal_id = module.aks.kubelet_identity_object_id
  aks_operator_object_id   = var.aks_operator_object_id
  github_environment       = var.github_environment
  github_oidc_subject      = local.github_oidc_subject
  identity_name            = local.github_identity_name
  location                 = module.resource_group.location
  resource_group_name      = module.resource_group.name
  tags                     = local.common_tags
}

module "observability" {
  count  = var.enable_observability ? 1 : 0
  source = "./modules/observability"

  application_insights_name = local.app_insights_name
  grafana_major_version     = var.grafana_major_version
  grafana_name              = local.grafana_name
  location                  = module.resource_group.location
  log_analytics_name        = local.log_analytics_name
  monitor_workspace_name    = local.monitor_name
  resource_group_name       = module.resource_group.name
  retention_in_days         = var.log_retention_days
  tags                      = local.common_tags
}

module "aks_monitoring" {
  count  = var.enable_observability ? 1 : 0
  source = "./modules/aks-monitoring"

  aks_id                        = module.aks.id
  aks_name                      = module.aks.name
  aks_oidc_issuer_url           = module.aks.oidc_issuer_url
  application_insights_id       = module.observability[0].application_insights_id
  location                      = module.resource_group.location
  log_analytics_workspace_id    = module.observability[0].log_analytics_workspace_id
  monitor_workspace_id          = module.observability[0].monitor_workspace_id
  resource_group_name           = module.resource_group.name
  tags                          = local.common_tags
  workload_namespace            = "northstar"
  workload_service_account_name = "northstar-sre-demo-workload"
}

module "sre_agent" {
  count  = var.enable_sre_agent ? 1 : 0
  source = "./modules/sre-agent"

  aks_id                                 = module.aks.id
  application_insights_app_id            = var.enable_observability ? module.observability[0].application_insights_app_id : null
  application_insights_connection_string = var.enable_observability ? module.observability[0].application_insights_connection_string : null
  location                               = module.resource_group.location
  managed_resource_ids = [
    module.resource_group.id,
  ]
  name                = local.sre_agent_name
  operator_object_id  = var.aks_operator_object_id
  resource_group_id   = module.resource_group.id
  resource_group_name = module.resource_group.name
  subscription_id     = var.subscription_id
  tags                = local.common_tags
  upgrade_channel     = var.sre_agent_upgrade_channel
}

module "teams_bridge" {
  count  = var.enable_teams_bridge ? 1 : 0
  source = "./modules/teams-bridge"

  allowed_user_object_id                 = var.teams_allowed_user_object_id
  application_insights_connection_string = module.observability[0].application_insights_connection_string
  bot_client_id                          = azuread_application.teams_bot[0].client_id
  bot_name                               = "bot-teams-${var.project_name}-${var.environment}-${local.suffix}"
  bot_tenant_id                          = var.tenant_id
  function_app_name                      = local.teams_bridge_name
  identity_name                          = "id-teams-${var.project_name}-${var.environment}-${local.suffix}"
  key_vault_name                         = local.teams_bridge_key_vault_name
  location                               = module.resource_group.location
  operator_object_id                     = var.aks_operator_object_id
  resource_group_id                      = module.resource_group.id
  resource_group_name                    = module.resource_group.name
  service_plan_name                      = "asp-teams-${var.project_name}-${var.environment}-${local.suffix}"
  sre_agent_endpoint                     = module.sre_agent[0].endpoint
  sre_agent_id                           = module.sre_agent[0].id
  storage_account_name                   = local.teams_bridge_storage_name
  tags                                   = local.common_tags
  teams_channel_id                       = var.teams_channel_id
  teams_team_id                          = var.teams_team_id
  teams_tenant_id                        = var.teams_tenant_id
}

check "teams_bridge_prerequisites" {
  assert {
    condition = !var.enable_teams_bridge || (
      var.enable_observability
      && var.enable_sre_agent
      && var.teams_tenant_id != null
      && var.teams_team_id != null
      && var.teams_channel_id != null
      && var.teams_allowed_user_object_id != null
    )
    error_message = "Teams bridge requires observability, SRE Agent, and all Teams tenant/team/channel/user IDs."
  }
}
