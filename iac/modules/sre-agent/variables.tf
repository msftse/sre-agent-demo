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

variable "resource_group_name" {
  description = "Parent resource group name."
  type        = string
}

variable "subscription_id" {
  description = "Subscription ID scanned by the native Azure Monitor incident platform."
  type        = string
}

variable "aks_id" {
  description = "AKS cluster resource ID used for read-only Kubernetes investigation."
  type        = string
}

variable "operator_object_id" {
  description = "Optional Microsoft Entra user object ID granted SRE Agent Administrator."
  type        = string
  default     = null
  nullable    = true
}

variable "managed_resource_ids" {
  description = "Azure resource group IDs the SRE Agent can discover."
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
