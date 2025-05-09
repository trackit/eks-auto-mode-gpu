variable "enable_gpu" {
  description = "Enable GPUs"
  type        = bool
  default     = false
}

variable "enable_neuron" {
  description = "Enable Neuron"
  type        = bool
  default     = false
}

variable "enable_autoscaling" {
  description = "Enable Autoscaling"
  type        = bool
  default     = false
}

variable "deploy_deepseek" {
  description = "Deploy DeepSeek"
  type        = bool
  default     = false
}

variable "deploy_fooocus" {
  description = "Deploy Fooocus"
  type        = bool
  default     = false 
}

variable "enable_auto_mode_node_pool" {
  description = "Enable EKS AutoMode NodePool"
  type        = bool
  default     = false
}

variable "owner" {
  description = "owner of the cluster"
  type = string
}

variable "project" {
  description = "Project name"
  type = string
}

variable "name" {
  description = "Name of the resource"
  type = string
}

variable "model_name" {
  description = "the model name"
  type = string
}

variable "max_model_len" {
  description = "the max char length that the model can take"
  type = string
}
