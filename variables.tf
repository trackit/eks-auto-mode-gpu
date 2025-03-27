variable "enable_deep_seek_gpu" {
  description = "Enable DeepSeek using GPUs"
  type        = bool
  default     = false
}

variable "enable_deep_seek_neuron" {
  description = "Enable DeepSeek using Neuron"
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
