terraform {

  backend "s3" {
    bucket         = "devops-kobi-tf-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_state_locking"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }

}

provider "aws" {
  region = var.region
}

# DNS
module "dns" {
  source = "../modules/dns"
  domain = var.domain
}

# Networking
module "networking" {
  source = "../modules/networking"
}

# EKS
module "eks" {
  source       = "../modules/eks"
  cluster_name = "fuego-eks"
  vpc_id       = module.networking.vpc_id
  subnet_ids   = module.networking.subnet_ids
}

data "aws_eks_cluster" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Kubernetes 
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# Node Role (manual)
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node_group_role" {
  name               = "eks-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "worker_node" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EKS Auth
module "eks_aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "20.8.4"

  create_aws_auth_configmap = true # creates auth map to allow user control of eks cluster

  depends_on = [module.eks]

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.node_group_role.arn # set manual node arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes"
      ]
    }
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::574436675271:user/manager-user"
      username = "manager-user"
      groups   = ["system:masters"]
    }
  ]
}

module "eks_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = ">= 20.10.0"

  cluster_name    = module.eks.cluster_name
  cluster_version = "1.30"
  subnet_ids      = module.networking.subnet_ids

  cluster_service_cidr = "172.20.0.0/16"

  name           = "fuego_nodes"
  desired_size   = 2
  min_size       = 1
  max_size       = 4
  instance_types = ["t3.medium"]
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  create         = true

  iam_role_additional_policies = {
    eks_worker = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    cni        = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    ecr_read   = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  iam_role_arn = aws_iam_role.node_group_role.arn # set manual node arn

  depends_on = [module.eks_aws_auth]

  tags = {
    Project = "fuego-cloud"
  }
}

# Kubernete yaml files 
module "k8s" {
  source = "../k8s"

  providers = {
    kubernetes = kubernetes
  }

  depends_on = [module.eks]
}


# CloudWatch
module "cloudwatch" {
  source    = "../modules/cloudwatch"
  namespace = "fuego-cloudwatch"

  providers = {
    kubernetes = kubernetes
  }

  depends_on = [module.k8s] # will wait for k8s to finish first

}
