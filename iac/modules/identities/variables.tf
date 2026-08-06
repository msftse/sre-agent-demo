variable "identity_name" {
  description = "GitHub Actions user-assigned managed identity name."
  type        = string
}

variable "location" {
  description = "Azure region for the managed identity."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the managed identity."
  type        = string
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to federate."
  type        = string
}

variable "github_environment" {
  description = "Protected GitHub Environment used in the OIDC subject."
  type        = string
}

variable "acr_id" {
  description = "Container Registry scope for push and pull roles."
  type        = string
}

variable "aks_id" {
  description = "AKS cluster scope for deployment roles."
  type        = string
}

variable "aks_kubelet_principal_id" {
  description = "Kubelet managed identity object ID receiving AcrPull."
  type        = string
}

variable "aks_operator_object_id" {
  description = "Optional Microsoft Entra user object ID receiving cluster-scoped AKS RBAC administrator access."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags applied to managed identity resources."
  type        = map(string)
}
