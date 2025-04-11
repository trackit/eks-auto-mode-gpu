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

# Define the required providers
provider "aws" {
  region = local.region # Change to your desired region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
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

resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "${var.name}-eks-cloudwatch-agent-role"
  tags = {
    Name        = "${var.name}-eks-cloudwatch-agent-role"
    Owner       = var.owner
    Project     = var.project
  }
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "pods.eks.amazonaws.com"
                ]
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_agent_role.name
}

resource "aws_eks_addon" "amazon_cloudwatch_observability" {

  cluster_name  = var.name
  addon_name    = "amazon-cloudwatch-observability"

  configuration_values = file("${path.module}/configs/amazon-cloudwatch-observability.json")

  pod_identity_association {
    role_arn = aws_iam_role.cloudwatch_agent_role.arn
    service_account = "cloudwatch-agent"
  }
}

resource "helm_release" "prometheus_adapter" {
  name       = "prometheus-adapter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-adapter"
  namespace  = "monitoring"
  create_namespace = true
  depends_on = [module.eks]

  values = [
    <<-EOT
    prometheus:
      url: http://prometheus-operator-kube-p-prometheus.monitoring.svc
    rules:
      custom:
        - seriesQuery: 'DCGM_FI_DEV_GPU_UTIL{exported_namespace!="",exported_pod!=""}'
          resources:
            overrides:
              exported_namespace: {resource: "namespace"}
              exported_pod: {resource: "pod"}
          name:
            matches: "DCGM_FI_DEV_GPU_UTIL"
            as: "gpu_utilization"
          metricsQuery: 'avg(DCGM_FI_DEV_GPU_UTIL{<<.LabelMatchers>>}) by (<<.GroupBy>>) / 100'
    EOT
  ]
}

resource "helm_release" "prometheus_operator" {
  name             = "prometheus-operator"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  depends_on = [module.eks]

  values = [
    <<-EOT
    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        serviceMonitorNamespaceSelector:
          matchNames:
            - gpu-monitoring
        serviceMonitorSelector:
          matchLabels:
            release: prometheus

    grafana:
      enabled: true
      adminPassword: "admin"

    alertmanager:
      enabled: true
    EOT
  ]
}

resource "helm_release" "dcgm_exporter" {
  name       = "dcgm-exporter"
  namespace  = "gpu-monitoring"
  repository = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  chart      = "dcgm-exporter"
  create_namespace = true
  depends_on = [module.eks]

  values = [
    <<-EOT
    service:
      type: ClusterIP
      port: 9400
    tolerations:
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
    EOT
  ]
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "gpu_utilization_hpa" {
  metadata {
    name      = "gpu-utilization-hpa"
    namespace = "deepseek"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "deepseek-gpu-vllm-chart"
    }

    min_replicas = 1
    max_replicas = 5

    metric {
      type = "Pods"

      pods {
        metric {
          name = "gpu_utilization"
        }

        target {
          type          = "AverageValue"
          average_value = "500m"
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 30
        select_policy                = "Max"
        policy {
          type          = "Pods"
          value         = 2
          period_seconds = 60
        }
      }

      scale_down {
        stabilization_window_seconds = 60
        select_policy                = "Min"
        policy {
          type          = "Percent"
          value         = 50
          period_seconds = 60
        }
      }
    }
  }
}
