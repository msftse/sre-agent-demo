resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  suffix              = coalesce(var.name_suffix, random_string.suffix.result)
  compact_project     = replace(var.project_name, "-", "")
  resource_group_name = "rg-${var.project_name}-${var.environment}-${local.suffix}"
  vnet_name           = "vnet-${var.project_name}-${var.environment}-${local.suffix}"
  aks_name            = "aks-${var.project_name}-${var.environment}-${local.suffix}"
  acr_name            = substr("acr${local.compact_project}${var.environment}${local.suffix}", 0, 50)
  github_identity_name = substr(
    "id-github-${var.project_name}-${var.environment}-${local.suffix}",
    0,
    128,
  )
  log_analytics_name = "log-${var.project_name}-${var.environment}-${local.suffix}"
  app_insights_name  = "appi-${var.project_name}-${var.environment}-${local.suffix}"
  monitor_name       = "amw-${var.project_name}-${var.environment}-${local.suffix}"
  grafana_name       = "amg-${substr(local.compact_project, 0, 6)}-${var.environment}-${local.suffix}"
  sre_agent_name     = "sre-${var.project_name}-${var.environment}-${local.suffix}"
  common_tags = merge(var.tags, {
    Environment     = var.environment
    ManagedBy       = "Terraform"
    Project         = var.project_name
    SecurityControl = "Ignore"
  })
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

  dns_service_ip      = var.aks_dns_service_ip
  kubernetes_version  = null
  location            = module.resource_group.location
  name                = local.aks_name
  node_count          = var.aks_node_count
  node_vm_size        = var.aks_node_vm_size
  pod_cidr            = var.aks_pod_cidr
  resource_group_name = module.resource_group.name
  service_cidr        = var.aks_service_cidr
  sku_tier            = var.aks_sku_tier
  subnet_id           = module.network.aks_subnet_id
  tags                = local.common_tags
  tenant_id           = var.tenant_id
}

module "identities" {
  source = "./modules/identities"

  acr_id                   = module.container_registry.id
  aks_id                   = module.aks.id
  aks_kubelet_principal_id = module.aks.kubelet_identity_object_id
  aks_operator_object_id   = var.aks_operator_object_id
  github_environment       = var.github_environment
  github_repository        = var.github_repository
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

module "sre_agent" {
  count  = var.enable_sre_agent ? 1 : 0
  source = "./modules/sre-agent"

  location = module.resource_group.location
  managed_resource_ids = [
    module.resource_group.id,
  ]
  name              = local.sre_agent_name
  resource_group_id = module.resource_group.id
  tags              = local.common_tags
  upgrade_channel   = var.sre_agent_upgrade_channel
}
