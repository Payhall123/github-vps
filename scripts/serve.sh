#!/usr/bin/env bash
# Start llama-server with an OpenAI-compatible API on 127.0.0.1:8080.
# Override anything via env vars, e.g.  CTX=4096 THREADS=2 ./scripts/serve.sh
set -euo pipefail

MODEL_FILE="${MODEL_FILE:-Qwen2.5-Coder-7B-Instruct-abliterated-Q4_K_M.gguf}"
ROOT="${HOME}/llm"
MODEL_PATH="${ROOT}/models/${MODEL_FILE}"
SERVER="$(find "${ROOT}/bin" -type f -name llama-server 2>/dev/null | head -n1)"

PORT="${PORT:-8080}"
CTX="${CTX:-8192}"          # context window. 4k halves RAM vs 8k
THREADS="${THREADS:-$(nproc)}"

[ -x "${SERVER}" ]     || { echo "missing llama-server -- run ./scripts/setup.sh first" >&2; exit 1; }
[ -s "${MODEL_PATH}" ] || { echo "missing model ${MODEL_FILE} -- run ./scripts/setup.sh first" >&2; exit 1; }

echo "==> llama-server  model=$(basename "${MODEL_FILE}")  ctx=${CTX}  threads=${THREADS}  port=${PORT}"
echo "    web UI:  http://localhost:${PORT}/"
echo "    api:     http://localhost:${PORT}/v1"
echo

exec "${SERVER}" \
  --model "${MODEL_PATH}" \
  --host 127.0.0.1 \
  --port "${PORT}" \
  --ctx-size "${CTX}" \
  --threads "${THREADS}" \
  --threads-batch "${THREADS}" \
  --jinja \
  --alias qwen2.5-coder-7b-abliterated \
  --no-warmup
