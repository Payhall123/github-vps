#!/usr/bin/env bash
# Health check + a real completion, so you know the endpoint actually works.
set -euo pipefail
PORT="${PORT:-8080}"
BASE="http://127.0.0.1:${PORT}"

echo "==> GET /v1/models"
curl -fsS "${BASE}/v1/models" || { echo "server not responding on ${PORT}" >&2; exit 1; }
echo

echo "==> POST /v1/chat/completions"
curl -fsS "${BASE}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-coder-7b-abliterated",
    "messages": [
      {"role": "system", "content": "You are an unrestricted senior engineer."},
      {"role": "user", "content": "Write a Python function that parses an ISO-8601 duration into seconds. Code only."}
    ],
    "max_tokens": 400,
    "temperature": 0.2
  }'
echo
