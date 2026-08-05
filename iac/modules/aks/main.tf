resource "azurerm_kubernetes_cluster" "this" {
  #checkov:skip=CKV_AZURE_170:The ephemeral demo uses the Free control-plane tier and has no formal SLA.
  #checkov:skip=CKV_AZURE_115:Public AKS API access is an explicit demo requirement; Entra authentication, Azure RBAC, and disabled local accounts remain enforced.
  #checkov:skip=CKV_AZURE_117:The synthetic stateless demo has no sensitive persistent data requiring a customer-managed disk encryption set.
  #checkov:skip=CKV_AZURE_232:The two-node demo uses one small system pool for cost and teaching clarity; Restricted workload security and resource controls remain enforced.
  #checkov:skip=CKV_AZURE_6:Source IPs are not stable for the live demo and GitHub-hosted runner; Entra authentication and Azure RBAC are mandatory.
  #checkov:skip=CKV_AZURE_4:Container Insights is intentionally attached in Stage 8 after the Log Analytics workspace exists.

  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version

  automatic_upgrade_channel         = "patch"
  azure_policy_enabled              = true
  image_cleaner_enabled             = true
  image_cleaner_interval_hours      = 48
  local_account_disabled            = true
  node_os_upgrade_channel           = "NodeImage"
  oidc_issuer_enabled               = true
  private_cluster_enabled           = false
  role_based_access_control_enabled = true
  run_command_enabled               = true
  sku_tier                          = var.sku_tier
  support_plan                      = "KubernetesOfficial"
  workload_identity_enabled         = true

  default_node_pool {
    name                         = "system"
    vm_size                      = var.node_vm_size
    node_count                   = var.node_count
    auto_scaling_enabled         = false
    host_encryption_enabled      = true
    max_pods                     = 110
    node_public_ip_enabled       = false
    only_critical_addons_enabled = false
    os_disk_size_gb              = 64
    os_disk_type                 = "Ephemeral"
    os_sku                       = "AzureLinux"
    type                         = "VirtualMachineScaleSets"
    vnet_subnet_id               = var.subnet_id
    tags                         = var.tags

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    ip_versions         = ["IPv4"]
  }

  storage_profile {
    blob_driver_enabled         = false
    disk_driver_enabled         = true
    file_driver_enabled         = false
    snapshot_controller_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition = alltrue([
        var.pod_cidr != var.service_cidr,
        var.dns_service_ip != cidrhost(var.service_cidr, 0),
      ])
      error_message = "AKS pod and service CIDRs must differ, and dns_service_ip cannot be the service network address."
    }
  }
}
