module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 20.10.0"

  # cluster basics
  cluster_name    = var.cluster_name
  cluster_version = "1.30"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  cluster_endpoint_public_access  = true # make cluster access endpoint public
  cluster_endpoint_private_access = false

  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  enable_irsa                              = true # IRSA is a EKS feature that allows K8 pods to assume iAM roles
  enable_cluster_creator_admin_permissions = true # Allows creator to manage cluster

  # enable control plane logging
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = {
    Project = "fuego-cloud"
  }
}
