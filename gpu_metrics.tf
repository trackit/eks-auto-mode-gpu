resource "helm_release" "dcgm_exporter" {
  count      = var.enable_autoscaling ? 1 : 0
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
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: eks.amazonaws.com/instance-gpu-count
              operator: Exists
    EOT
  ]
}

resource "helm_release" "prometheus_operator" {
  count            = var.enable_autoscaling ? 1 : 0
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
            app.kubernetes.io/name: dcgm-exporter
    EOT
  ]
}

resource "helm_release" "prometheus_adapter" {
  count      = var.enable_autoscaling ? 1 : 0
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