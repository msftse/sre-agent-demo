variable "name" {
  description = "AKS cluster name."
  type        = string
}

variable "location" {
  description = "Azure region for AKS."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Optional Log Analytics workspace resource ID used by Container Insights."
  type        = string
  default     = null
  nullable    = true
}

variable "managed_prometheus_enabled" {
  description = "Enable the Azure Monitor managed Prometheus metrics profile."
  type        = bool
  default     = false
}

variable "resource_group_name" {
  description = "Resource group containing AKS."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID for managed AKS authentication."
  type        = string
}

variable "subnet_id" {
  description = "AKS node subnet resource ID."
  type        = string
}

variable "node_vm_size" {
  description = "VM SKU for system nodes."
  type        = string
}

variable "node_count" {
  description = "Fixed system node count."
  type        = number
}

variable "sku_tier" {
  description = "AKS control plane SKU tier."
  type        = string
}

variable "kubernetes_version" {
  description = "Optional pinned Kubernetes version. Null selects the current regional default."
  type        = string
  default     = null
}

variable "pod_cidr" {
  description = "Azure CNI Overlay pod CIDR."
  type        = string
}

variable "service_cidr" {
  description = "Kubernetes service CIDR."
  type        = string
}

variable "dns_service_ip" {
  description = "Kubernetes DNS service IP."
  type        = string
}

variable "tags" {
  description = "Tags applied to AKS and its system node pool."
  type        = map(string)
}
