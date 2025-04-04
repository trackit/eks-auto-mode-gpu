resource "helm_release" "fooocus_gpu" {
  count = var.enable_gpu && var.deploy_fooocus ? 1 : 0
  name  = "fooocus-gpu"
  chart = "./fooocus-chart"
  create_namespace = true
  wait             = false
  replace          = true
  namespace        = "fooocus"

  set {
    name  = "image.repository"
    value = aws_ecr_repository.fooocus-ecr.repository_url
  }

  values = [file("./fooocus-chart/values.yaml")]

  depends_on = [module.eks, kubernetes_manifest.gpu_nodepool]
}
