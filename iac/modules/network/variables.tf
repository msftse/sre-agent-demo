variable "name" {
  description = "Virtual network name."
  type        = string
}

variable "location" {
  description = "Azure region for network resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing network resources."
  type        = string
}

variable "vnet_address_space" {
  description = "Virtual network address spaces."
  type        = list(string)
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS node subnet."
  type        = list(string)
}

variable "public_ip_name" {
  description = "Reserved ingress public IP resource name."
  type        = string
}

variable "tags" {
  description = "Tags applied to all taggable network resources."
  type        = map(string)
}
