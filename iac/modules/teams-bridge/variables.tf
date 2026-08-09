variable "identity_name" {
  description = "User-assigned identity name used by the Teams bridge."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique storage account name used by Functions and conversation state."
  type        = string
}

variable "storage_table_name" {
  description = "Table name used for Teams and SRE thread mappings."
  type        = string
  default     = "teamsbridge"
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name for interactive bot and MCP credentials."
  type        = string
}

variable "service_plan_name" {
  description = "Flex Consumption service plan name."
  type        = string
}

variable "function_app_name" {
  description = "Globally unique Teams bridge Function App name."
  type        = string
}

variable "bot_name" {
  description = "Azure Bot resource name."
  type        = string
}

variable "location" {
  description = "Azure region for the Teams bridge resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the Teams bridge."
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID used as the AzAPI parent for storage."
  type        = string
}

variable "bot_client_id" {
  description = "Client ID of the corporate-tenant single-tenant bot application."
  type        = string
}

variable "bot_tenant_id" {
  description = "Microsoft Entra tenant ID containing the bot application."
  type        = string
}

variable "allowed_user_object_id" {
  description = "Only Microsoft Entra user object ID allowed to trigger inbound investigations."
  type        = string
}

variable "operator_object_id" {
  description = "Optional demo-tenant operator object ID allowed to create and rotate bridge secrets."
  type        = string
  default     = null
  nullable    = true
}

variable "teams_tenant_id" {
  description = "Microsoft Teams tenant ID accepted by the bridge."
  type        = string
}

variable "teams_team_id" {
  description = "Only Microsoft Team ID accepted by the bridge."
  type        = string
}

variable "teams_channel_id" {
  description = "Only Microsoft Teams channel ID accepted by the bridge."
  type        = string
}

variable "sre_agent_id" {
  description = "Azure SRE Agent resource ID granted to the bridge identity."
  type        = string
}

variable "sre_agent_endpoint" {
  description = "Azure SRE Agent data-plane endpoint called by the bridge."
  type        = string
}

variable "application_insights_connection_string" {
  description = "Existing Application Insights connection string used for bridge telemetry."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to taggable Teams bridge resources."
  type        = map(string)
}