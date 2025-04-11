resource "helm_release" "prometheus_adapter" {
  count      = var.enable_deepseek_autoscaling ? 1 : 0
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
  count            = var.enable_deepseek_autoscaling ? 1 : 0
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
  count      = var.enable_deepseek_autoscaling ? 1 : 0
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
  count = var.enable_deepseek_autoscaling ? 1 : 0

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

resource "kubectl_manifest" "ingress_class_params" {
  count = var.enable_deepseek_autoscaling ? 1 : 0
  yaml_body = file("${path.module}/ingress/ingress-class-params.yaml")
  apply_only = true
  wait_for_rollout = false
  depends_on = [module.eks]

  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

resource "kubectl_manifest" "ingress_class" {
  count = var.enable_deepseek_autoscaling ? 1 : 0
  yaml_body = file("${path.module}/ingress/ingress-class.yaml")
  apply_only = true
  wait_for_rollout = false
  depends_on = [module.eks]

  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

resource "kubectl_manifest" "ingress" {
  count = var.enable_deepseek_autoscaling ? 1 : 0
  yaml_body = file("${path.module}/ingress/ingress.yaml")
  apply_only = true
  wait_for_rollout = false
  depends_on = [module.eks]

  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

data "kubernetes_ingress_v1" "deepseek_ingress" {
  count = var.enable_deepseek_autoscaling ? 1 : 0
  metadata {
    name      = "deepseek-ingress"
    namespace = "deepseek"
  }
  depends_on = [ kubectl_manifest.ingress ]
}

output "deepseek_ingress_hostname" {
  description = "The hostname of the DeepSeek Ingress"
  value = var.enable_deepseek_autoscaling ? data.kubernetes_ingress_v1.deepseek_ingress[0].status[0].load_balancer[0].ingress[0].hostname : "No Ingress created"
}
