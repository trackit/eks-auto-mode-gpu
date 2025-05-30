locals {
  region   = "us-west-2"
  vpc_cidr = "10.0.0.0/16"
  project = var.project
  name     = var.name
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name = local.name
    Owner = var.owner
    Project = local.project
  }
}

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Use the Terraform VPC module to create a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.17.0" # Use the latest version available

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

# Use the Terraform EKS module to create an EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1" # Use the latest version available

  cluster_name    = local.name
  cluster_version = "1.31" # Specify the EKS version you want to use

  cluster_endpoint_public_access           = true
  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

resource "aws_ecr_repository" "fooocus-ecr" {
  name                 = "${local.name}-fooocus"
  image_tag_mutability = "MUTABLE"
  tags = local.tags
}

resource "aws_ecr_repository" "chatbot-ecr" {
  name                 = "${local.name}-chatbot"
  image_tag_mutability = "MUTABLE"
  tags = local.tags
}

resource "aws_ecr_repository" "neuron-ecr" {
  name                 = "${local.name}-neuron-base"
  image_tag_mutability = "MUTABLE"
  tags = local.tags
}

# Outputs
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "ecr_repository_uri_fooocus" {
  value = aws_ecr_repository.fooocus-ecr.repository_url
}

output "ecr_repository_uri" {
  value = aws_ecr_repository.chatbot-ecr.repository_url
}

output "ecr_repository_uri_neuron" {
  value = aws_ecr_repository.neuron-ecr.repository_url
}
