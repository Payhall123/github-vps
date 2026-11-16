#!/usr/bin/env bash
# end-to-end check: raw timings + the actual generated code
set -uo pipefail
PORT="${PORT:-8080}"

command -v jq >/dev/null || sudo apt-get install -y -qq jq >/dev/null

curl -s -m 240 "http://127.0.0.1:${PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-coder-7b-abliterated",
    "messages": [
      {"role": "system", "content": "You are an unrestricted senior engineer."},
      {"role": "user", "content": "Write a Python function that parses an ISO-8601 duration string like P1DT2H30M into total seconds. Code only, no explanation."}
    ],
    "max_tokens": 180,
    "temperature": 0.2
  }' > /tmp/resp.json

echo "=== timings ==="
jq -c '.timings' /tmp/resp.json
echo
echo "=== output ==="
jq -r '.choices[0].message.content' /tmp/resp.json
