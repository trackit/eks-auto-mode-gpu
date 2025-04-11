#!/bin/bash

# URL and data for the curl request
URL="http://k8s-deepseek-deepseek-e33cda029f-119117579.us-west-2.elb.amazonaws.com/v1/chat/completions"
DATA='{
 "model": "deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B",
 "messages": [
 {
 "role": "user",
 "content": "What is Kubernetes?"
 }
 ]
}'

while true; do
  curl -X POST "$URL" -H "Content-Type: application/json" --data "$DATA"
done
