resource "kubectl_manifest" "ingress_class_params" {
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

resource "kubectl_manifest" "deepseek_ingress" {
  count = var.enable_autoscaling ? 1 : 0
  yaml_body = file("${path.module}/ingress/ingress-deepseek.yaml")
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
  count = var.enable_autoscaling ? 1 : 0
  metadata {
    name      = "deepseek-ingress"
    namespace = "deepseek"
  }
  depends_on = [ kubectl_manifest.deepseek_ingress ]
}

output "deepseek_ingress_hostname" {
  description = "The hostname of the DeepSeek Ingress"
  value = var.enable_autoscaling ? data.kubernetes_ingress_v1.deepseek_ingress[0].status[0].load_balancer[0].ingress[0].hostname : "No Ingress created"
}

resource "kubectl_manifest" "fooocus_ingress" {
  count = var.enable_autoscaling ? 1 : 0
  yaml_body = file("${path.module}/ingress/ingress-fooocus.yaml")
  apply_only = true
  wait_for_rollout = false
  depends_on = [module.eks]

  lifecycle {
    ignore_changes = [
      yaml_body
    ]
  }
}

data "kubernetes_ingress_v1" "fooocus_ingress" {
  count = var.enable_autoscaling ? 1 : 0
  metadata {
    name      = "fooocus-ingress"
    namespace = "fooocus"
  }
  depends_on = [ kubectl_manifest.fooocus_ingress ]
}

output "fooocus_ingress_hostname" {
  description = "The hostname of the Fooocus Ingress"
  value = var.enable_autoscaling ? data.kubernetes_ingress_v1.fooocus_ingress[0].status[0].load_balancer[0].ingress[0].hostname : "No Ingress created"
}
