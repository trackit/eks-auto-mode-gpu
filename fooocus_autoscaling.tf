resource "kubernetes_horizontal_pod_autoscaler_v2" "fooocus_gpu_utilization_hpa" {
  count = var.enable_autoscaling ? 1 : 0

  metadata {
    name      = "gpu-utilization-hpa"
    namespace = "fooocus"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "fooocus-deployment"
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
