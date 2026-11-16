# Codespace → private uncensored coding-model endpoint

Runs an **abliterated (refusal-removed) Qwen2.5-Coder-7B** behind llama.cpp's
OpenAI-compatible API, inside a GitHub Codespace. Your local editor talks to it
over an SSH tunnel — nothing is exposed to the public internet.

Base repo: [l0n3m4n/github-vps](https://github.com/l0n3m4n/github-vps) (Kali/Codespaces notes).
This directory adds the inference layer.

---

## What you get

| | |
|---|---|
| Machine | 4 vCPU / 16 GB RAM / 32 GB disk (`standardLinux32gb`) |
| Model | Qwen2.5-Coder-7B-Instruct-**abliterated**, Q4_K_M, 4.68 GB |
| Runtime | llama.cpp `llama-server`, CPU-only, no CUDA needed |
| Endpoint | `http://127.0.0.1:8080/v1` — OpenAI-compatible (`/v1/chat/completions`, `/v1/models`) |
| Throughput | realistically **4–7 tok/s** on 4 vCPU. Fine for autocomplete and short edits, painful for whole-file rewrites |
| Access | `gh codespace ports forward` → loopback only. No ngrok, no public port |

## Layout

```
.devcontainer/devcontainer.json   pins machine size, forwards 8080 privately
scripts/setup.sh                  installs llama.cpp release build + downloads GGUF (idempotent)
scripts/serve.sh                  starts llama-server
scripts/smoke.sh                  health check + real completion
clients/connect.ps1               Windows: opens the port forward, keeps box awake
clients/continue-config.yaml      Continue.dev config pointing at localhost:8080
```

## Quick start

### 1. Push this into your fork

```bash
git clone https://github.com/<you>/github-vps
cp -r .devcontainer scripts clients .gitignore <you>/github-vps/   # from this folder
cd <you>/github-vps && git add -A && git commit -m "add local LLM endpoint" && git push
```

### 2. Create the codespace

New codespace on your fork → **...** (next to *Create codespace*) → pick
**4-core · 16 GB · 32 GB**. The `hostRequirements` in `devcontainer.json` already
asks for that size, but picking it explicitly avoids a rebuild prompt.

### 3. Provision (once per codespace)

```bash
./scripts/setup.sh      # ~3-6 min: binaries + 4.7 GB download
```

### 4. Serve

```bash
./scripts/serve.sh      # foreground; keep this terminal
```

Then in a second codespace terminal:

```bash
./scripts/smoke.sh
```

### 5. From your own machine

```powershell
.\clients\connect.ps1        # keep this window open
```

```powershell
curl.exe http://localhost:8080/v1/models
```

Point Continue / Cline / Roo / any OpenAI client at:

```
base URL : http://localhost:8080/v1
api key  : sk-local-no-auth      (ignored, just needs to be non-empty)
model    : qwen2.5-coder-7b-abliterated
```

### 6. Restarting later

A codespace auto-stops when idle (default 30 min, max 240 min — set it under
**Settings → Codespaces → Default idle timeout**). After a stop, the disk is
intact but the processes are gone:

```bash
gh codespace ssh -c <name>          # wakes it
./scripts/serve.sh
```

## Alternative: Ollama instead of llama.cpp

If you'd rather have model management and swapping:

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama run hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-abliterated-GGUF:Q4_K_M
```

API lands on `:11434/v1` — change `PORT` and the forwarded port to match.
llama.cpp uses less RAM and starts faster, which matters on a 16 GB box.

## Model options

Everything below is the `huihui-ai/Qwen2.5-Coder-7B-Instruct-abliterated`
lineage (abliterated with [Heretic](https://github.com/p-e-w/heretic), Apache-2.0).
Trade quality for tokens/sec:

```bash
MODEL_FILE=Qwen2.5-Coder-7B-Instruct-abliterated-Q6_K.gguf ./scripts/setup.sh   # 6.25 GB, best quality that fits
MODEL_FILE=Qwen2.5-Coder-7B-Instruct-abliterated-Q4_K_S.gguf ./scripts/setup.sh  # 4.46 GB, slightly faster
MODEL_FILE=Qwen2.5-Coder-7B-Instruct-abliterated-Q3_K_M.gguf ./scripts/setup.sh  # 3.81 GB, if you need headroom
```

Other quant repos with identical weights: `mradermacher/...-GGUF`,
`RichardErkhov/huihui-ai_-_...-gguf`, `nyan-ame/Qwen2.5-Coder-7B-Instruct-Abliterated-GGUF`.
Set `MODEL_REPO` alongside `MODEL_FILE` to use one.

Expect ~3 tok/s at Q6 and ~7 tok/s at Q3 — the model is 7B and there's **no GPU**.
If you want speed more than capability, a 3B abliterated coder at Q4 will do
15–20 tok/s but writes noticeably worse code.

Context: default here is 8192. `CTX=4096 ./scripts/serve.sh` roughly halves KV-cache
RAM and is often enough for single-file edits. Bump to `16384` only if you have
RAM to spare — 7B Q4_K_M at 16k context will push ~13 GB.

## The quota reality — read this before relying on it

GitHub Free gives **120 core-hours/month** and **15 GB-month storage**. A 4-core
machine burns 4 core-hours per wall-clock hour, so:

- **~30 hours/month** of 4-core, or **~60 hours/month** of 2-core.
- The model alone is 4.68 GB of your 15 GB-month storage budget, and stopped
  codespaces still count. Add `export HF_HOME=/workspaces/cache` if you want the
  download to live on the repo volume instead.
- Exceed the quota and codespaces stop starting until the next cycle. On a Free
  account there is no spending limit to blow past, so you won't get a surprise
  bill — you just get locked out.

Translation: ~1 hour of coding a day. Not a 24/7 server, and it cannot be one —
there's no public IP and no uptime guarantee.

## Advantages over ngrok tunneling

- **No public URL.** Port forward is loopback-only. The `FreeVPS` approach
  publishes your desktop to the internet via an unauthenticated tunnel; this
  doesn't.
- **Files persist** between stop/start (until the ~30-day deletion, or 15 GB cap).
- **Nothing third-party in the path.** Just GitHub + a released llama.cpp binary
  from the upstream `ggml-org` repo + Hugging Face weights.

## Troubleshooting

**`llama-server: error while loading shared libraries`** — old base image.
`sudo apt-get install -y libgomp1` and retry.

**Download stalls at ~4.6 GB** — rerun `./scripts/setup.sh`; it resumes with `curl -C -`.

**`curl: (6) Could not resolve host: huggingface.co`** — HF is rate limited or
blocked; set `HF_TOKEN` to a read token and rerun.

**Port already in use** — a stale `llama-server` survived. `pkill -f llama-server`.

**`gh codespace ports forward` hangs with no output** — that's normal, it's the
tunnel. Verify from another shell with `curl http://localhost:8080/v1/models`.

**Very slow (< 2 tok/s)** — you're on a 2-core machine. Check
`gh codespace list` → machine column, recreate at 4-core, or drop to a Q3 quant.

## Legal / policy notes

Running open-weight models you've downloaded is fine. Two things to keep in mind:

- The abliterated weights have refusals removed. You own what you generate with
  them — there's no provider filter to blame. Keep it to code.
- Codespaces is for software development, per GitHub's Acceptable Use Policy.
  Personal dev use like this is squarely within it; reselling access or serving
  third parties from the box is not, and Codespaces activity is attributable to
  your account.

## License

Scripts here: MIT, same as the base repo. Model weights: Apache-2.0.
