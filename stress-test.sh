#!/bin/bash

URL=$(terraform output -raw deepseek_ingress_hostname)

if [[ -z "$URL" || "$URL" == "No Ingress created" ]]; then
  echo "❌ Error: Ingress hostname not found. Please ensure the Ingress is created and the output is set correctly."
  exit 1
fi

URL_PATH="/v1/chat/completions"
FULL_URL="http://$URL$URL_PATH"

DATA=$(cat <<EOF
{
  "model": "deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B",
  "messages": [
    {
      "role": "user",
      "content": "What is Kubernetes?"
    }
  ]
}
EOF
)

while true; do
  echo "➡️  Send request to $FULL_URL"
  curl -s -X POST "$FULL_URL" \
    -H "Content-Type: application/json" \
    --data "$DATA" | jq -r '.choices[0].message.content'

done
