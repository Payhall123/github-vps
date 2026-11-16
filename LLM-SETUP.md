# Codespace → private uncensored coding-model endpoint

Runs an **abliterated (refusal-removed) Qwen2.5-Coder-7B** behind llama.cpp's
OpenAI-compatible API, inside a GitHub Codespace. Your local editor talks to it
over an SSH tunnel — nothing is exposed to the public internet.

Base repo: [l0n3m4n/github-vps](https://github.com/l0n3m4n/github-vps) (Kali/Codespaces notes).
This directory adds the inference layer.

**Status: verified working.** Measured on `github-vps-llm-5gpq79vv6946hpx5p`,
4 vCPU / 16 GB / 32 GB, 2026-11-16:

```
prompt   : 14.6 tok/s
generate : 7.6–7.9 tok/s   (Q4_K_M, 8192 ctx, 4 threads)
RAM      : 4.8 GB used, 11.2 GB available
disk     : 5.3 GB of 32 GB used (4.5 GB is the model)
```

---

## What you get

| | |
|---|---|
| Machine | 4 vCPU / 16 GB RAM / 32 GB disk (`standardLinux32gb`) |
| Model | Qwen2.5-Coder-**abliterated** 7B Q4_K_M (4.68 GB) and 3B Q4_K_M (1.5 GB) |
| Runtime | llama.cpp `llama-server` (nightly `ubuntu-x64` build), CPU-only, no CUDA |
| Endpoint | `http://127.0.0.1:8080/v1` — OpenAI-compatible (`/v1/chat/completions`, `/v1/models`) |
| Throughput | ~7.6 tok/s. Fine for chat, autocomplete and short edits — slow for whole-file rewrites |
| Access | `gh codespace ports forward` → loopback only. No ngrok, no public port |

## Layout

```
.devcontainer/devcontainer.json   pins machine size, forwards 8080 privately, installs sshd
scripts/setup.sh                  llama.cpp release build + GGUF download (idempotent, resumable)
scripts/serve.sh                  starts llama-server
scripts/smoke.sh                  health check
scripts/e2e.sh                    real completion + timings
clients/connect.ps1               Windows: opens the port forward, wakes the box
clients/continue-config.yaml      Continue.dev config pointing at localhost:8080
```

## Quick start

### 1. Create the codespace

New codespace on your fork → **...** next to *Create codespace* → **4-core · 16 GB · 32 GB**.

```bash
gh codespace create -R <you>/github-vps -m standardLinux32gb -b main --idle-timeout 240m
```

`--idle-timeout 240m` is the maximum allowed; the default 30 min will stop the box
mid-session.

### 2. Provision (once per codespace)

```bash
./scripts/setup.sh      # ~1 min on fast pipe: binaries + 4.7 GB download
```

It resolves the newest `llama-b<NNNNN>-bin-ubuntu-x64.tar.gz` from the llama.cpp
releases API (note: upstream ships nightly tags as prereleases and `.tar.gz`,
not the old `.zip`), extracts to `~/llm/bin/`, then pulls the GGUF from
Hugging Face with `curl -C -` so an interrupted download resumes.

### 3. Serve

```bash
./scripts/serve.sh      # 7B on :8080, foreground; keep this terminal
```

The 3B on a second port (much faster to prompt — see the prefill section), after
stopping the 7B:

```bash
PORT=8081 CTX=16384 ALIAS=qwen2.5-coder-3b-abliterated \
MODEL_FILE=Qwen2.5-Coder-3B-Instruct-abliterated-Q4_K_M.gguf ./scripts/serve.sh
```

Only one server at a time on a 4-core box.

Second terminal:

```bash
./scripts/smoke.sh      # curl /v1/models
./scripts/e2e.sh        # real completion + timing report
```

### 4. From your own machine

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

### 5. Restarting later

A codespace auto-stops when idle. The disk survives; the processes don't.

```bash
gh codespace ssh -c <name>          # wakes it
./scripts/serve.sh
```

⚠️ An open `gh codespace ports forward` counts as activity and prevents the idle
stop. Close it (Ctrl+C) when you're done, then:

```bash
gh codespace stop -c <name>         # stop burning core-hours
```

## Alternative: Ollama instead of llama.cpp

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama run hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-abliterated-GGUF:Q4_K_M
```

API lands on `:11434/v1` — change `PORT` in `serve.sh` and the forwarded port to match.
llama.cpp uses less RAM and starts faster, which matters on a 16 GB box.

## Model options

All from the `huihui-ai/Qwen2.5-Coder-7B-Instruct-abliterated` lineage
(abliterated with [Heretic](https://github.com/p-e-w/heretic), Apache-2.0).
Trade quality for tokens/sec:

```bash
MODEL_FILE=Qwen2.5-Coder-7B-Instruct-abliterated-Q6_K.gguf ./scripts/setup.sh   # 6.25 GB, best quality that fits
MODEL_FILE=Qwen2.5-Coder-7B-Instruct-abliterated-Q4_K_S.gguf ./scripts/setup.sh  # 4.46 GB, slightly faster
MODEL_FILE=Qwen2.5-Coder-7B-Instruct-abliterated-Q3_K_M.gguf ./scripts/setup.sh  # 3.81 GB, more RAM headroom

# 3B — the one that's actually responsive through OpenCode
MODEL_REPO=bartowski/Qwen2.5-Coder-3B-Instruct-abliterated-GGUF \
MODEL_FILE=Qwen2.5-Coder-3B-Instruct-abliterated-Q4_K_M.gguf ./scripts/setup.sh   # 1.5 GB

# Qwen3 4B — the only one here that reliably drives OpenCode's agent loop
MODEL_REPO=unsloth/Qwen3-4B-Instruct-2507-GGUF \
MODEL_FILE=Qwen3-4B-Instruct-2507-Q4_K_M.gguf ./scripts/setup.sh                  # 2.5 GB
```

Other repos with identical weights: `mradermacher/...-GGUF`,
`RichardErkhov/huihui-ai_-_...-gguf`,
`nyan-ame/Qwen2.5-Coder-7B-Instruct-Abliterated-GGUF`.
Set `MODEL_REPO` alongside `MODEL_FILE` to use one.

~3 tok/s at Q6, ~9 tok/s at Q3 — it's a 7B with **no GPU**. A 3B abliterated coder at
Q4 hits 15–20 tok/s but writes noticeably worse code.

Context defaults to 8192. `CTX=4096 ./scripts/serve.sh` roughly halves KV-cache RAM
and is usually enough for single-file edits. `CTX=16384` fits in 16 GB but leaves
little headroom.

## Using it from OpenCode

Add a provider to `~/.config/opencode/opencode.json` (OpenCode V2 shape):

```jsonc
{
  "providers": {
    "codespace-q3": {
      "name": "Codespace llama.cpp (Qwen3 4B)",
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": {
        "baseURL": "http://127.0.0.1:8081/v1",
        "apiKey": "sk-local-no-auth",
        "headerTimeout": 600000,
        "chunkTimeout": 600000
      },
      "models": {
        "qwen3-4b-instruct-2507": {
          "modelID": "qwen3-4b-instruct-2507",
          "name": "Qwen3 4B Instruct 2507 (local, tools work)",
          "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
          "compatibility": { "maxTokensField": "max_tokens", "streamUsage": false },
          "limit": { "context": 16384, "output": 2048 }
        }
      }
    }
  }
}
```

Then:

```bash
opencode run --model codespace-q3/qwen3-4b-instruct-2507 "read package.json and list the scripts"
```

or pick it from `/models`. To make it the default, add `"model": "codespace-q3/qwen3-4b-instruct-2507"` at the root.

### Do NOT use Qwen2.5-Coder for tool calling

This is the trap that cost the most time. **Ab-literated Qwen2.5-Coder will not emit
tool calls**, at any size. It writes the call as markdown prose instead:

```
tool_calls=0  finish_reason=stop
content: ```json
{"name": "read", "arguments": {"path": ["C:\\...a.txt", "C:\\...b.txt"]}}
```
```

So `read` gets an array where the schema says string, no tool executes, and OpenCode
sits there having "done nothing". Measured, same prompt, same server:

| Model | Native `tool_calls` | Notes |
| --- | --- | --- |
| Qwen2.5-Coder-3B-abliterated | **0 / 3** | fenced JSON, wrong argument types |
| Qwen2.5-Coder-7B-abliterated | **0 / 2** | fenced JSON array of calls |
| Qwen3-4B-Instruct-2507 | **3 / 3** | `finish_reason=tool_calls`, correct strings |

It is not the template: `POST /apply-template` confirms llama.cpp injects the `<tools>`
block and the "wrap calls in `<tool_call>`" instruction. The models ignore it. Abliteration
plus Qwen2.5-Coder's weak tool training is the cause — it is a **completion/chat model**,
not an agent model.

Use the Qwen2.5-Coder models for what they're good at (fill-in-the-middle, explaining
code, single-shot generation in the web UI), and Qwen3 for anything that has to call a tool.

### Why 16384 context, not 8192

OpenCode's system prompt plus tool definitions is **~5.5k tokens** before your first
message. At 8192 the request overflows and llama-server errors out. 16k also leaves
room for a few file reads.

### The prefill problem (important)

Prefill is the cost of *reading* your prompt before it writes anything. Measured on
4 vCPU with OpenCode's actual request:

| Model | Prefill | Generate | OpenCode system prompt (~5.5k tok) |
| --- | --- | --- | --- |
| 7B Q4_K_M | 13–14.5 tok/s | 7.6 tok/s | ~6.5 min before the first token |
| 3B Q4_K_M | 26.9–34 tok/s | 9.0 tok/s | ~3.4 min before the first token |

OpenCode sends 5–10k tokens every turn, so the 7B spends ~6.5 minutes *reading* the
harness before answering, and the 3B ~3.4 minutes. Neither is interactive-grade.

Verified end to end: `opencode run --model codespace3b/qwen2.5-coder-3b-abliterated
"Reply with exactly: opencode-ok"` returned `opencode-ok` after 206 s of prefill.

Practical reading of that:

- **7B** — good for one-shot chat in the llama.cpp web UI or a small `curl`; not
  workable as an OpenCode driver.
- **3B** — workable for `opencode run "one task"` invocations where you accept ~3–5
  minutes per turn. Still rough for long interactive sessions, because context grows
  and prefill grows with it.
- **Run one server at a time.** Two `llama-server` processes on 4 vCPU starve each
  other — observed at 0.47 tok/s. Stop the 7B before starting the 3B.

If you need interactive agentic coding, keep a hosted model for the chat loop and use
this box for cheap batch work (`opencode run` over a list of files, overnight).

## The quota reality

GitHub Free: **120 core-hours/month**, **15 GB-month storage**. A 4-core machine
burns 4 core-hours per wall-clock hour:

- **~30 h/month** at 4-core, **~60 h/month** at 2-core.
- The model is 4.68 GB of the 15 GB-month storage budget, and stopped codespaces
  still count. Downloading it, running it for an hour, and stopping costs roughly
  0.2 GB-month of storage plus 4 core-hours — the dominant cost is wall-clock.
- Exceed the quota and codespaces refuse to start until the next cycle. On a Free
  account there's no spending limit to blow past, so no surprise bill — just a lockout.

Translation: ~1 hour a day of coding. Not a 24/7 server, and it cannot be one —
no public IP, no uptime guarantee.

## Why this beats the ngrok approaches

- **No public URL.** The port forward is loopback-only. The ngrok/RDP repos publish
  your desktop to the internet through an unauthenticated tunnel; this doesn't.
- **Files persist** across stop/start, until the ~30-day deletion or the storage cap.
- **Nothing third-party in the trust path.** GitHub + a released llama.cpp binary
  from upstream `ggml-org` + Hugging Face weights.

## Troubleshooting

**`no ubuntu-x64 build found`** — llama.cpp changed its release layout before; the
resolver matches `llama-b<digits>-bin-ubuntu-x64.tar.gz` across the 10 newest
releases. If it ever breaks again, pin manually:

```bash
curl -fL -o /tmp/l.tgz https://github.com/ggml-org/llama.cpp/releases/download/b12428/llama-b12428-bin-ubuntu-x64.tar.gz
mkdir -p ~/llm/bin && tar -xzf /tmp/l.tgz -C ~/llm/bin
```

**`error while loading shared libraries`** — `sudo apt-get install -y libgomp1`.

**Download stalls** — rerun `./scripts/setup.sh`; `curl -C -` resumes.

**`Could not resolve host: huggingface.co`** — set `HF_TOKEN` to a read token and rerun.

**Port 8080 busy** — a stale server survived: `pkill -f llama-server`.

**`python3: command not found`** — the base image is minimal; `e2e.sh` only needs `jq`
(installs it itself).

**`gh codespace ports forward` prints nothing** — normal, it's the tunnel. Verify from
another shell with `curl http://localhost:8080/v1/models`.

**< 2 tok/s** — you're on a 2-core box. Check `gh codespace list`, recreate at 4-core,
or drop to a Q3 quant.

## Legal / policy notes

Running open-weight models you've downloaded is fine. Two things to keep in mind:

- The abliterated weights have refusals removed. You own what you generate with them —
  there's no provider filter to blame. Keep it to code.
- Codespaces is for software development per GitHub's Acceptable Use Policy. Personal
  dev use like this sits inside it; reselling access or serving third parties from the
  box does not. Codespaces activity is attributable to your account.

## License

Scripts here: MIT, same as the base repo. Model weights: Apache-2.0.
