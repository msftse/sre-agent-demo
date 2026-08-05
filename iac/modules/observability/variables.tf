variable "application_insights_name" {
  description = "Application Insights component name."
  type        = string
}

variable "grafana_name" {
  description = "Azure Managed Grafana workspace name."
  type        = string
}

variable "grafana_major_version" {
  description = "Managed Grafana major version."
  type        = string
}

variable "location" {
  description = "Azure region for observability resources."
  type        = string
}

variable "log_analytics_name" {
  description = "Log Analytics workspace name."
  type        = string
}

variable "monitor_workspace_name" {
  description = "Azure Monitor workspace name for managed Prometheus."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing observability resources."
  type        = string
}

variable "retention_in_days" {
  description = "Log Analytics and Application Insights retention days."
  type        = number
}

variable "tags" {
  description = "Tags applied to observability resources."
  type        = map(string)
}
