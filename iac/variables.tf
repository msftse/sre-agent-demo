variable "subscription_id" {
  description = "Azure subscription ID where the demo resources will be created. Set with TF_VAR_subscription_id or a non-committed tfvars file."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID."
  }
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID associated with the target subscription."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.tenant_id))
    error_message = "tenant_id must be a valid UUID."
  }
}

variable "location" {
  description = "Azure region for all regional resources."
  type        = string
  default     = "swedencentral"

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.location))
    error_message = "location must use the Azure CLI region format, for example swedencentral."
  }
}

variable "environment" {
  description = "Short deployment environment name used in resource naming and tags."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,12}$", var.environment))
    error_message = "environment must contain 2-12 lowercase letters, numbers, or hyphens."
  }
}

variable "project_name" {
  description = "Short project name used in resource naming and tags."
  type        = string
  default     = "sre-agent-demo"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.project_name))
    error_message = "project_name must contain 3-24 lowercase letters, numbers, or hyphens."
  }
}

variable "name_suffix" {
  description = "Optional deterministic 4-8 character suffix. When null, Terraform creates and persists a random suffix in local state."
  type        = string
  default     = null

  validation {
    condition     = var.name_suffix == null || can(regex("^[a-z0-9]{4,8}$", var.name_suffix))
    error_message = "name_suffix must be null or 4-8 lowercase alphanumeric characters."
  }
}

variable "tags" {
  description = "Additional tags merged with mandatory project tags. SecurityControl=Ignore cannot be overridden."
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "Address space for the demo virtual network."
  type        = list(string)
  default     = ["10.42.0.0/16"]
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS node subnet."
  type        = list(string)
  default     = ["10.42.0.0/22"]
}

variable "aks_pod_cidr" {
  description = "Overlay CIDR assigned to AKS pods. Must not overlap the VNet or service CIDR."
  type        = string
  default     = "10.244.0.0/16"
}

variable "aks_service_cidr" {
  description = "CIDR assigned to Kubernetes services."
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "Kubernetes DNS service IP inside aks_service_cidr."
  type        = string
  default     = "10.0.0.10"
}

variable "aks_node_vm_size" {
  description = "VM SKU for the AKS system node pool."
  type        = string
  default     = "Standard_D2ds_v5"
}

variable "aks_node_count" {
  description = "Fixed node count for the ephemeral demo system pool."
  type        = number
  default     = 2

  validation {
    condition     = var.aks_node_count >= 2 && var.aks_node_count <= 5
    error_message = "aks_node_count must be between 2 and 5."
  }
}

variable "aks_sku_tier" {
  description = "AKS control plane SKU tier."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier must be Free, Standard, or Premium."
  }
}

variable "aks_operator_object_id" {
  description = "Optional Microsoft Entra user object ID receiving cluster-scoped AKS RBAC administrator access."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.aks_operator_object_id == null || can(regex("^[0-9a-fA-F-]{36}$", var.aks_operator_object_id))
    error_message = "aks_operator_object_id must be null or a valid UUID."
  }
}

variable "acr_sku" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to federate to the deployment identity."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format."
  }
}

variable "github_repository_owner_id" {
  description = "Optional immutable GitHub repository owner ID for post-July-2026 OIDC subjects."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.github_repository_owner_id == null || var.github_repository_owner_id > 0
    error_message = "github_repository_owner_id must be null or a positive integer."
  }
}

variable "github_repository_id" {
  description = "Optional immutable GitHub repository ID for post-July-2026 OIDC subjects."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.github_repository_id == null || var.github_repository_id > 0
    error_message = "github_repository_id must be null or a positive integer."
  }
}

variable "github_environment" {
  description = "Protected GitHub Environment used by the delivery workflow and OIDC subject. This demo supports the fixed name demo."
  type        = string
  default     = "demo"

  validation {
    condition     = var.github_environment == "demo"
    error_message = "github_environment must be demo because the delivery workflow uses that environment."
  }
}

variable "enable_observability" {
  description = "Create Azure Monitor, Log Analytics, Application Insights, and Managed Grafana resources. Enabled in Stage 8."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Log Analytics and Application Insights retention. Azure service minimums apply."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "grafana_major_version" {
  description = "Azure Managed Grafana major version requested when observability is enabled."
  type        = string
  default     = "12"
}

variable "enable_sre_agent" {
  description = "Create the Azure SRE Agent resource. Enabled only after the Stage 11 capability and permission checks."
  type        = bool
  default     = false
}

variable "sre_agent_upgrade_channel" {
  description = "Azure SRE Agent release channel."
  type        = string
  default     = "Stable"

  validation {
    condition     = contains(["Stable", "Preview"], var.sre_agent_upgrade_channel)
    error_message = "sre_agent_upgrade_channel must be Stable or Preview."
  }
}

variable "enable_teams_bridge" {
  description = "Create the Stage 12 Microsoft Teams bot bridge infrastructure."
  type        = bool
  default     = false
}

variable "teams_tenant_id" {
  description = "Microsoft Teams tenant ID that hosts the target Team and channel. The single-tenant bot app is created in tenant_id."
  type        = string
  default     = null
  nullable    = true
}

variable "teams_team_id" {
  description = "Target Microsoft Team ID locked into the bridge."
  type        = string
  default     = null
  nullable    = true
}

variable "teams_channel_id" {
  description = "Target Microsoft Teams channel ID locked into the bridge."
  type        = string
  default     = null
  nullable    = true
}

variable "teams_allowed_user_object_id" {
  description = "Only Microsoft Entra user object ID allowed to start an investigation from Teams."
  type        = string
  default     = null
  nullable    = true
}

variable "teams_personal_chat_enabled" {
  description = "Allow Azure SRE Agent conversations from Teams personal chat."
  type        = bool
  default     = false
}

variable "teams_personal_chat_access_mode" {
  description = "Personal chat authorization mode: the configured allowed user or any authenticated user in teams_tenant_id."
  type        = string
  default     = "allowed_user"

  validation {
    condition     = contains(["allowed_user", "tenant"], var.teams_personal_chat_access_mode)
    error_message = "teams_personal_chat_access_mode must be allowed_user or tenant."
  }
}

variable "teams_personal_chat_turns_per_hour" {
  description = "Maximum personal-chat investigation turns started by one user in one UTC hour."
  type        = number
  default     = 10

  validation {
    condition = (
      var.teams_personal_chat_turns_per_hour >= 1
      && var.teams_personal_chat_turns_per_hour <= 100
      && floor(var.teams_personal_chat_turns_per_hour) == var.teams_personal_chat_turns_per_hour
    )
    error_message = "teams_personal_chat_turns_per_hour must be an integer between 1 and 100."
  }
}
