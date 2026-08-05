variable "name" {
  description = "Azure SRE Agent resource name."
  type        = string
}

variable "location" {
  description = "Azure region for the SRE Agent."
  type        = string
}

variable "resource_group_id" {
  description = "Parent resource group ID."
  type        = string
}

variable "managed_resource_ids" {
  description = "Azure resource group IDs the SRE Agent can discover and manage."
  type        = list(string)
}

variable "upgrade_channel" {
  description = "SRE Agent release channel."
  type        = string
}

variable "tags" {
  description = "Tags applied to the SRE Agent."
  type        = map(string)
}
