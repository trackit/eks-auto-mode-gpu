resource "helm_release" "deepseek_gpu" {
  count            = var.enable_deep_seek_gpu ? 1 : 0
  name             = "deepseek-gpu"
  chart            = "./vllm-chart"
  create_namespace = true
  wait             = false
  replace          = true
  namespace        = "deepseek"

  values = [
    <<-EOT
    nodeSelector:
      owner: "${"devops"}"
      instanceType: "gpu"
    tolerations:
      - key: "nvidia.com/gpu"
        operator: "Exists"
        effect: "NoSchedule"
    resources:
      limits:
        cpu: "32"
        memory: 100G
        nvidia.com/gpu: "1"
      requests:
        cpu: "16"
        memory: 30G
        nvidia.com/gpu: "1"
    command: "vllm serve ${var.model_name} --max_model_len ${var.max_model_len}"

    livenessProbe:
      httpGet:
        path: /health
        port: 8000
      initialDelaySeconds: 1800
      periodSeconds: 10

    readinessProbe:
      httpGet:
        path: /health
        port: 8000
      initialDelaySeconds: 1800
      periodSeconds: 5
    EOT
  ]
  depends_on = [module.eks, kubernetes_manifest.gpu_nodepool]
}

resource "helm_release" "deepseek_neuron" {
  count            = var.enable_deep_seek_neuron ? 1 : 0
  name             = "deepseek-neuron"
  chart            = "./vllm-chart"
  create_namespace = true
  wait             = false
  replace          = true
  namespace        = "deepseek"

  values = [
    <<-EOT
    image:
      repository: ${aws_ecr_repository.neuron-ecr.repository_url}
      tag: 0.1
      pullPolicy: IfNotPresent

    nodeSelector:
      owner: "${"devops"}"
      instanceType: "neuron"
    tolerations:
      - key: "aws.amazon.com/neuron"
        operator: "Exists"
        effect: "NoSchedule"

    command: "vllm serve ${var.model_name} --device neuron --tensor-parallel-size 2 --max-num-seqs 4 --block-size 8 --use-v2-block-manager --max-model-len ${var.max_model_len}"

    env:
      - name: NEURON_RT_NUM_CORES
        value: "2"
      - name: NEURON_RT_VISIBLE_CORES
        value: "0,1"
      - name: VLLM_LOGGING_LEVEL
        value: "INFO"

    resources:
      limits:
        cpu: "30"
        memory: 64G
        aws.amazon.com/neuron: "1"
      requests:
        cpu: "30"
        memory: 64G
        aws.amazon.com/neuron: "1"

    livenessProbe:
      httpGet:
        path: /health
        port: 8000
      initialDelaySeconds: 1800
      periodSeconds: 10

    readinessProbe:
      httpGet:
        path: /health
        port: 8000
      initialDelaySeconds: 1800
      periodSeconds: 5
    EOT
  ]
  depends_on = [module.eks, kubernetes_manifest.neuron_nodepool]
}
