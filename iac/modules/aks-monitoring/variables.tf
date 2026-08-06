variable "aks_id" {
  description = "AKS cluster resource ID receiving monitoring associations."
  type        = string
}

variable "aks_name" {
  description = "AKS cluster name used in monitoring resource names."
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL used for workload identity federation."
  type        = string
}

variable "application_insights_id" {
  description = "Application Insights resource ID receiving application traces."
  type        = string
}

variable "location" {
  description = "Azure region for monitoring resources."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for Container Insights and control-plane logs."
  type        = string
}

variable "monitor_workspace_id" {
  description = "Azure Monitor workspace resource ID for managed Prometheus."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the AKS cluster and monitoring resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to monitoring resources."
  type        = map(string)
}

variable "workload_namespace" {
  description = "Kubernetes namespace containing the telemetry-producing workload."
  type        = string
}

variable "workload_service_account_name" {
  description = "Kubernetes service account federated to the telemetry managed identity."
  type        = string
}