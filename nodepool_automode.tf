resource "kubernetes_manifest" "gpu_nodepool" {
  count = var.enable_auto_mode_node_pool && var.enable_gpu ? 1 : 0
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
  count = var.enable_auto_mode_node_pool && var.enable_neuron ? 1 : 0
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