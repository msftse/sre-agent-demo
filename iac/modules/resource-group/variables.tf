variable "name" {
  description = "Resource group name."
  type        = string
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
}

variable "resource_provider_namespaces" {
  description = "Resource providers to register explicitly."
  type        = set(string)
}

variable "tags" {
  description = "Tags applied to the resource group."
  type        = map(string)
}
