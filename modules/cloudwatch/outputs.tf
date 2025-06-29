output "cloudwatch_namespace" {
  description = "the name space where cloudwatch agent is deployed"
  value       = kubernetes_namespace.cloudwatch.metadata[0].name
}
