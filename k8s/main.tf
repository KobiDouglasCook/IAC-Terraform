locals {
  deployment_yaml = yamldecode(file("${path.module}/deployment.yaml"))
  service_yaml    = yamldecode(file("${path.module}/service.yaml"))
}

resource "kubernetes_manifest" "deployment" {
  manifest = local.deployment_yaml
}

resource "kubernetes_manifest" "service" {
  manifest = local.service_yaml
}
