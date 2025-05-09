# You can choose what you want to deploy
enable_gpu = false
enable_neuron = false
enable_auto_mode_node_pool = false
enable_autoscaling = false
deploy_deepseek = false
deploy_fooocus = false
name = "eks-automode-gpu"
project = "EKS gpu cluster"
# replace by your Firstname Lastname for the tagging compliance
owner = "Maxime"
# You can change the model name to any other DeepSeek model from the Hugging Face model hub
# https://huggingface.co/deepseek-ai/DeepSeek-R1
model_name = "deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B"
max_model_len = 2048