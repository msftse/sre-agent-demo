output "id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity used for ACR pulls."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "node_resource_group" {
  description = "AKS-managed node resource group."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "AKS workload identity OIDC issuer URL."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "principal_id" {
  description = "AKS control plane managed identity principal ID."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}
