# resource "aws_iam_role" "eks_node_role" {
#   name = "eks-node-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Effect = "Allow",
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "eks_node_policy" {
#   role       = aws_iam_role.eks_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
# }

# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#   role       = aws_iam_role.eks_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
# }

# resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
#   role       = aws_iam_role.eks_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# }

# resource "kubernetes_manifest" "gpu_nodeclass" {
#   count = var.enable_auto_mode_node_pool && var.enable_deep_seek_gpu ? 1 : 0
#   manifest = {
#     apiVersion = "eks.amazonaws.com/v1"
#     kind       = "NodeClass"
#     metadata = {
#       name = "gpu-nodeclass"
#     }
#     spec = {
#       role = aws_iam_role.eks_node_role.name
#       ephemeralStorage = {
#         size = "50Gi"
#       }
#     }
#   }

#   depends_on = [module.eks]
# }

resource "kubernetes_manifest" "gpu_nodepool" {
  count = var.enable_auto_mode_node_pool && var.enable_deep_seek_gpu ? 1 : 0
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "gpu-nodepool"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            owner = "devops"
            instanceType = "gpu"
          }
        }
        spec = {
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = "default"
            #name  = "gpu-nodeclass"
          }
          taints = [
            {
              key    = "nvidia.com/gpu"
              value  = "Exists"
              effect = "NoSchedule"
            }
          ]
          requirements = [
            {
              key      = "eks.amazonaws.com/instance-family"
              operator = "In"
              values   = ["g4", "g5", "g6", "g6e", "p5", "p4"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            }
          ]
        }
      }
      limits = {
        cpu    = "1000"
        memory = "1000Gi"
      }
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_manifest" "neuron_nodepool" {
  count = var.enable_auto_mode_node_pool && var.enable_deep_seek_neuron ? 1 : 0
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "neuron-nodepool"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            owner = "devops"
            instanceType = "neuron"
          }
        }
        spec = {
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = "default"
          }
          taints = [
            {
              key    = "aws.amazon.com/neuron"
              value  = "Exists"
              effect = "NoSchedule"
            }
          ]
          requirements = [
            {
              key      = "eks.amazonaws.com/instance-family"
              operator = "In"
              values   = ["inf2"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            }
          ]
        }
      }
      limits = {
        cpu    = "1000"
        memory = "1000Gi"
      }
    }
  }

  depends_on = [module.eks]
}