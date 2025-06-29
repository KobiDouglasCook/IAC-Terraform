# helper functions
locals {
  cwagent_docs_raw = split("---", templatefile("${path.module}/cloudwatch-agent.yaml.tpl", {
    namespace = var.namespace
  }))

  # Trim whitespace from each doc
  cwagent_docs_trimmed = [for doc in local.cwagent_docs_raw : trim(doc, " \t\n")]

  # Decode each YAML doc into a manifest map (skip empty docs)
  cwagent_docs = [
    for doc in local.cwagent_docs_trimmed :
    length(doc) > 0 ? yamldecode(doc) : null
  ]
}

resource "kubernetes_namespace" "cloudwatch" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_manifest" "cloudwatch_agent" {
  for_each   = { for idx, doc in local.cwagent_docs : idx => doc if doc != null }
  manifest   = each.value
  depends_on = [kubernetes_namespace.cloudwatch]
}



