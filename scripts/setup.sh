#!/usr/bin/env bash
# One-time provisioning: llama.cpp binaries + the model weights.
# Re-running is safe; already-downloaded pieces are skipped.
set -uo pipefail

MODEL_REPO="${MODEL_REPO:-bartowski/Qwen2.5-Coder-7B-Instruct-abliterated-GGUF}"
MODEL_FILE="${MODEL_FILE:-Qwen2.5-Coder-7B-Instruct-abliterated-Q4_K_M.gguf}"

ROOT="${HOME}/llm"
BIN_DIR="${ROOT}/bin"
MODEL_DIR="${ROOT}/models"
mkdir -p "${BIN_DIR}" "${MODEL_DIR}"

SERVER=""
find_server() { find "${BIN_DIR}" -type f -name llama-server 2>/dev/null | head -n1; }
SERVER="$(find_server)"

die() { echo "!! $*" >&2; exit 1; }

echo "==> installing runtime deps"
sudo apt-get update -qq
sudo apt-get install -y -qq curl ca-certificates libgomp1 >/dev/null

# ---------------------------------------------------------------- llama.cpp
if [ -z "${SERVER}" ]; then
  echo "==> resolving latest llama.cpp linux x64 build"

  api="https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=10"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    rel=$(curl -fsSL -H "Authorization: Bearer ${GITHUB_TOKEN}" "${api}") \
      || die "GitHub API request failed"
  else
    rel=$(curl -fsSL "${api}") || die "GitHub API request failed"
  fi

  # upstream ships llama-b<NNNNN>-bin-ubuntu-x64.tar.gz on nightly tags
  url=$(printf '%s' "${rel}" \
        | tr ',' '\n' \
        | grep -o 'https://github.com/[^"]*llama-b[0-9]*-bin-ubuntu-x64\.tar\.gz' \
        | head -n1)

  [ -n "${url}" ] || die "no ubuntu-x64 build found in recent llama.cpp releases"
  echo "    ${url}"

  tmp=$(mktemp -d)
  curl -fL --retry 3 -o "${tmp}/llama.tar.gz" "${url}" || die "binary download failed"
  tar -xzf "${tmp}/llama.tar.gz" -C "${BIN_DIR}" || die "extract failed"
  rm -rf "${tmp}"

  SERVER="$(find_server)"
  [ -n "${SERVER}" ] || die "llama-server not found after extract"
else
  echo "==> llama.cpp already present"
fi
chmod +x "${SERVER}"
echo "    server: ${SERVER}"
"${SERVER}" --version 2>&1 | head -n 2 || true

# -------------------------------------------------------------------- model
MODEL_PATH="${MODEL_DIR}/${MODEL_FILE}"
if [ ! -s "${MODEL_PATH}" ]; then
  echo "==> downloading ${MODEL_FILE} (this is the slow part)"
  hf_url="https://huggingface.co/${MODEL_REPO}/resolve/main/${MODEL_FILE}?download=true"
  # -C - makes an interrupted download resumable
  if [ -n "${HF_TOKEN:-}" ]; then
    curl -fL --retry 5 --retry-delay 2 -C - \
      -H "Authorization: Bearer ${HF_TOKEN}" \
      -o "${MODEL_PATH}" "${hf_url}" || die "model download failed"
  else
    curl -fL --retry 5 --retry-delay 2 -C - \
      -o "${MODEL_PATH}" "${hf_url}" || die "model download failed"
  fi
else
  echo "==> model already present"
fi

echo
echo "==> done"
du -sh "${ROOT}"/* 2>/dev/null || true
echo
echo "    start the server with:  ./scripts/serve.sh"
