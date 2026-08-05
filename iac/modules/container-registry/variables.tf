variable "name" {
  description = "Globally unique Azure Container Registry name."
  type        = string
}

variable "location" {
  description = "Azure region for the registry."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the registry."
  type        = string
}

variable "sku" {
  description = "Azure Container Registry SKU."
  type        = string
}

variable "tags" {
  description = "Tags applied to the registry."
  type        = map(string)
}
