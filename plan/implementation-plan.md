# CognitiveOS Implementation Plan

Version: 1.0.0-draft

## Overview

CognitiveOS is an intent-centric, AI-native operating system built on Alpine Linux. The human speaks or types what they want; the AI handles everything. No apps, no browsers, no permission layers.

This plan covers the implementation of all 10 repos in the CognitiveOS-Project organization, from foundation to distribution.

## Repo Map

| Repo | Layer | Language | Role |
|------|-------|----------|------|
| `product-specs` | Architecture | Markdown/JSON | Standards, schemas, .cgp format |
| `sdlc` | Development | Markdown | Implementation plan, workflow, CI/CD |
| `cpm` | Package | Go | Cognitive Package Manager |
| `core-mcp-bridges` | Hardware | Go | MCP hardware tool servers |
| `inference` | Brain | Go/C | LLM inference engine |
| `cognitiveosd` | System | Go | Background system daemon |
| `cli` | UI | Go | Bubble Tea TUI frontend |
| `cognitiveos-distro` | Distribution | Shell/Docker | Alpine image builder |
| `cgp-template` | Ecosystem | Template | .cgp skill boilerplate |
| `registry-server` | Infrastructure | Go | .cgp notary proxy (metadata + checksum, no file hosting) |

## Dependency Graph

```
product-specs ───────────────────────────── defines schemas for all
    │
    ├── cpm ───────── depends on .cgp spec
    │
    ├── core-mcp-bridges ─── depends on MCP conventions spec
    │
    ├── inference ──── depends on inference-api spec
    │
    ├── cognitiveosd ─ depends on cognitiveosd-api spec
    │   │                  depends on cpm (to spawn patches)
    │   │                  depends on core-mcp-bridges (to route tools)
    │   │                  depends on inference (to manage Wide Model)
    │   │
    ├── cli ────────── depends on cognitiveosd (socket client)
    │
    ├── registry-server ─── depends on registry-api spec, dependency-validation spec
    │
    └── cgp-template ─ depends on .cgp format spec

cognitiveos-distro ───── depends on all built binaries
```

## Phase Breakdown

### Phase 0: Foundation ✅ COMPLETE

**Repos:** `product-specs`, `sdlc`

| Deliverable | Status |
|-------------|--------|
| Vision and philosophy document | ✅ `specs/vision.md` |
| Architecture spec | ✅ `specs/architecture.md` |
| Filesystem hierarchy | ✅ `specs/filesystem-hierarchy.md` |
| MCP conventions | ✅ `specs/mcp-conventions.md` |
| .cgp format spec | ✅ `specs/cgp-format.md` |
| System codes spec | ✅ `specs/system-codes.md` |
| cognitive.json JSON Schema | ✅ `schemas/cognitive.schema.json` |
| cognitiveosd API spec | ✅ `specs/cognitiveosd-api.md` |
| CLI spec | ✅ `specs/cli-spec.md` |
| cpm spec | ✅ `specs/cpm-spec.md` |
| Inference API spec | ✅ `specs/inference-api.md` |
| Registry API spec | ✅ `specs/registry-api.md` |
| Security model | ✅ `specs/security-model.md` |
| Distro build spec | ✅ `specs/distro-build-spec.md` |
| MCP bridge schemas (×5) | ✅ `schemas/*-mcp.json` |
| Implementation plan | ➡️ This document |

### Phase 1: Core Package Manager

**Repos:** `cpm`

**Goal:** Working `cpm` CLI that can install, remove, list, and verify .cgp archives.

| Task | Dependencies | Est. effort |
|------|-------------|-------------|
| `cpm init` — .cgp skeleton generator | None | Small |
| `cpm install` — local .cgp file extraction to `/cognitiveos/patches/` | None | Medium |
| `cpm install` — registry resolution (HTTP client to registry-server API) | registry-api spec | Medium |
| `cpm remove` — delete patch directory | None | Small |
| `cpm list` — enumerate installed patches | None | Small |
| `cpm info` — display manifest | None | Small |
| `cpm verify` — checksum and schema validation | cognitive.schema.json | Small |
| Hardware audit integration (read /proc/meminfo, statfs) | filesystem-hierarchy spec | Medium |
| Dependency resolution | None | Medium |
| `cpm search` — registry search client | registry-api spec | Small |
| `cpm download-weights` — standalone weight download from HF Hub | manifest-fields spec | Medium |
| `cpm install` — auto-download weights when manifest declares `weights.remote.source` | manifest-fields spec | Medium |
| `cpm init --template gguf-model` — template for model publishers | manifest-fields spec | Small |

**Definition of done:**
- `cpm install ./sample.cgp` works on Alpine Linux
- `cpm list` shows installed patches
- `cpm verify` catches malformed archives
- Hardware audit rejects install on low-RAM device
- All operations logged to `/cognitiveos/logs/cpm.log`
- `cpm download-weights --provider hf --kind wide --type gguf <name>` downloads and places model at `/cognitiveos/models/wide/active/`
- `cpm install` on a `.cgp` with `weights.remote` auto-downloads the model before hardware audit
- `cpm init --template gguf-model` scaffolds a model-publisher manifest with `weights.remote` block
- No auth required for public HF models

### Phase 2: Hardware Bridges

**Repos:** `core-mcp-bridges`

**Goal:** Five working MCP servers that the Wide Model can call to control hardware.

**Bridge: display-mcp**

| Task | Backend | Est. effort |
|------|---------|-------------|
| `cognitiveos.display.render_image` | fbv or fbi | Small |
| `cognitiveos.display.render_video` | mpv --vo=drm | Small |
| `cognitiveos.display.screenshot` | cat /dev/fb0 > file | Small |
| `cognitiveos.display.clear` | ioctl FB_BLANK | Small |
| MCP stdio server wrapper | MCP SDK | Small |
| Registration with cognitiveosd socket | cognitiveosd-api | Small |

**Bridge: audio-mcp** — Same pattern using ALSA (aplay, arecord, amixer)

**Bridge: network-mcp** — Same pattern using iw, wpa_supplicant, ip

**Bridge: gpio-mcp** — Same pattern using libgpiod

**Bridge: serial-mcp** — Same pattern using /dev/tty*

**Definition of done:**
- Each bridge runs as a standalone MCP stdio binary
- `cognitiveos.display.render_image /path/to/image.jpg` displays on framebuffer
- `cognitiveos.audio.capture` records from microphone
- `cognitiveos.network.scan` lists Wi-Fi networks
- Each bridge registers with cognitiveosd on startup

### Phase 3: Inference Engine

**Repos:** `inference`

**Goal:** Working inference engine that can load and run GGUF models, exposed via an Ollama-compatible API. Architecture uses a **vendored llama.cpp C source + thin CGo bridge** — no `llama-cli` subprocess.

| Task | Dependencies | Est. effort |
|------|-------------|-------------|
| Vendor `llama.cpp` git submodule (pinned commit) | None | Small |
| `bridge.go` — single `import "C"` file wrapping llama.h API | None | Medium |
| `cgobackend.go` — `CgoBackend` struct implementing `Backend` interface | bridge.go | Medium |
| `loadopts.go` — `LoadOptions{NumCtx, GPULayers, Threads}` | None | Small |
| cmake + gcc toolchain in `Dockerfile.build` | None | Medium |
| Register `--backend cgo` in `cmd/coginfer/main.go` | cgobackend.go | Small |
| `POST /api/generate` — CGo-backed inference | server.go, bridge.go | Medium |
| `POST /api/chat` | generate handler | Small |
| `GET /api/tags` — model listing | None | Small |
| `GET /cognitiveos/status` — resource reporting (CGo stats) | inference-api spec | Small |
| `GET /cognitiveos/capabilities` — hardware detection | inference-api spec | Small |
| Wire `LoadOptions` from HTTP request params to `backend.Load()` | server.go | Small |
| Resource negotiation with cognitiveosd | cognitiveosd-api | Medium |
| Idle timeout and auto-unload (calls `CgoBackend.Unload()`) | None | Small |
| Model swap (unload old, load new via CGo) | None | Medium |
| Fix `cmd/cograw/main.go` bugs — undefined `llamaBin`, `verifyModel()`, `ramMB` | None | Small |
| Replace `exec.Command("llama-cli")` in cograw with CGo bridge | bridge.go | Medium |
| JSON-RPC 2.0 handler for Raw Model (wrapping bridge calls) | None | Medium |

**Definition of done:**
- Raw Model loads from `/cognitiveos/models/raw/raw-model.gguf` via CGo bridge (no subprocess)
- `POST /api/generate` produces coherent completions via CGo
- Resource usage reported correctly in `/cognitiveos/status`
- Inference engine communicates with cognitiveosd for load/unload
- `CLIBackend` and `--backend cli` flag removed (Phase 5)
- `--backend` defaults to `"cgo"` in production (CGO_ENABLED=1) and `"mock"` when CGO_ENABLED=0

### Phase 4: System Daemon

**Repos:** `cognitiveosd`

**Goal:** The central daemon that coordinates all other components.

| Task | Dependencies | Est. effort |
|------|-------------|-------------|
| Unix socket listener at `/cognitiveos/run/daemon.sock` | filesystem-hierarchy | Medium |
| Message protocol handler (12 message types) | cognitiveosd-api | Large |
| Input forward (cli → daemon → Wide Model → cli) | inference | Medium |
| MCP server process lifecycle (spawn, monitor, kill) | None | Medium |
| Tool registry (index tools from MCP server registration) | None | Medium |
| Tool invocation routing (Wide Model → MCP server) | core-mcp-bridges | Medium |
| Hardware audit loop (read /proc/meminfo, statfs every 60s) | None | Medium |
| System code handling (5 codes) | system-codes spec | Medium |
| Wide Model lifecycle management | inference | Medium |
| Graceful startup and shutdown sequence | None | Medium |
| cgroup management for MCP servers | security-model | Medium |
| seccomp filter application | security-model | Medium |

**Definition of done:**
- Daemon starts, creates socket, loads Raw Model
- CLI can send input → forwarded to Wide Model → response returned to CLI
- MCP servers spawn and register automatically
- `system_code security` terminates all untrusted processes
- Hardware audit runs every 60 seconds
- Daemon survives MCP server crashes

### Phase 5: User Interface

**Repos:** `cli`

**Goal:** Bubble Tea TUI that replaces the desktop — the human face of CognitiveOS.

| Task | Dependencies | Est. effort |
|------|-------------|-------------|
| Idle screen ("ready") | None | Small |
| Text input mode (listening) | None | Small |
| Processing mode with spinner | None | Small |
| Responding mode with text output | None | Small |
| Socket connection to cognitiveosd | cognitiveosd | Medium |
| Voice input integration (audio-mcp capture) | core-mcp-bridges | Medium |
| Framebuffer overlay management (yield/reclaim) | core-mcp-bridges | Medium |
| Media mode (image/video display) | core-mcp-bridges | Medium |
| Code entry mode (masked input) | None | Small |
| Error display and recovery suggestions | None | Small |
| Crash recovery (automatic restart via inittab) | None | Small |
| Keybindings (all defined in cli-spec) | cli-spec | Small |

**Definition of done:**
- CLI boots on tty1 via inittab
- Connects to cognitiveosd and shows "ready"
- Typing a command → Wide Model responds → output displayed
- "Show me my photos" → framebuffer shows image
- Voice input captures and processes speech
- CLI crash → respawned automatically

### Phase 6: Distribution Image

**Repos:** `cognitiveos-distro`

**Goal:** Bootable Alpine Linux image with all CognitiveOS components baked in.

| Task | Dependencies | Est. effort |
|------|-------------|-------------|
| Overlay assembly script | All above binaries compiled | Medium |
| Alpine mkimage ISO generation | distro-build-spec | Medium |
| Alpine mkimage RPi SD card generation | distro-build-spec | Medium |
| Custom inittab integration | None | Small |
| First-boot setup automation | None | Small |
| Docker-based cross-compilation environment | None | Medium |
| Makefile with iso/rpi/clean targets | None | Small |
| Image signing and checksum generation | None | Small |

**Definition of done:**
- `make iso` produces a bootable CognitiveOS ISO
- `make rpi` produces a Raspberry Pi SD card image
- Boot on QEMU → CLI appears → "CognitiveOS ready"
- Raw Model loads automatically

### Phase 7: Registry and Ecosystem

**Repos:** `registry-server`, `cgp-template`

**Goal:** Usable package notary proxy and developer template.

The registry is a **notary proxy** — it does not host `.cgp` files. Publishers provide a canonical `download_url` and a `sha256` checksum; the registry stores metadata and redirects clients to the download URL. This avoids file storage scaling concerns and allows publishers to host archives on their own infrastructure (GitHub Releases, S3, etc.).

| Task | Dependencies | Est. effort | Status |
|------|-------------|-------------|--------|
| `GET /v1/search` — text search across name, description, tags | registry-api | Small | ✅ Done |
| `GET /v1/patches/{name}` — latest version metadata | registry-api | Small | ✅ Done |
| `GET /v1/patches/{name}/{version}` — version-specific metadata with full manifest | registry-api | Small | ✅ Done |
| `GET /v1/patches/{name}/{version}/download` — HTTP 302 redirect to `download_url` | registry-api | Small | ✅ Done |
| `POST /v1/patches` — JSON-only publish with `manifest`, `sha256`, `download_url` | registry-api | Medium | ✅ Done |
| `PUT /v1/patches/{name}/{version}` — publish new version, URL validated against body | registry-api | Small | ✅ Done |
| A1-A10 publish-time validation (manifest parse, schema, SHA-256 format, dep cycles, file refs, hardware bounds, URL reachability) | dependency-validation spec | Large | ✅ Done |
| Scoped token auth (`publish` scope for POST/PUT, `admin` scope for status/validate) | None | Medium | ✅ Done |
| `PATCH /v1/patches/{name}/{version}/status` — set active/deprecated/buggy | registry-api | Small | ✅ Done |
| `POST /v1/patches/{name}/{version}/validate` — re-run A1-A10 on stored manifest | registry-api | Small | ✅ Done |
| `GET /v1/patches/{name}/dependencies` — dependency tree for a package | registry-api | Small | ✅ Done |
| File-backed store (JSON file, survives restarts, SQLite adapter interface ready) | None | Medium | ✅ Done |
| `POST .../unlock` — unlock code verification | registry-api | Medium | Partial |
| SQLite metadata index (upgrade from file-backed JSON) | None | Medium | Pending |
| cgp-template with sample patch | cgp-format spec | Small | ✅ Done |
| cgp-template README and documentation | None | Small | ✅ Done |
| Registry API spec documenting notary proxy (no file hosting) | — | Small | ✅ Done |
| `publish-cgp.sh` updated for notary pattern (JSON + sha256 + download-url) | — | Small | ✅ Done |

**Definition of done:**
- `cpm search email` returns results from the registry ✅
- `cpm publish ./skill.cgp --download-url <url>` registers checksum in registry ✅
- `cpm install <name>` downloads from `download_url` after registry redirect ✅
- Unlock code flow works end-to-end ⬜ (stub implementation)
- A1-A10 validation rejects malformed publishes at registry level ✅
- `cpm init my-skill` creates a valid .cgp skeleton ✅

## Build Order with Milestones

```
M0  ─── Foundation complete                         (NOW)
  │
M1  ─── cpm can install local .cgp files            (Phase 1)
  │
M2  ─── display-mcp and audio-mcp working           (Phase 2)
  │
M3  ─── Raw Model loads and responds                (Phase 3)
  │
M4  ─── cognitiveosd runs all components            (Phase 4)
  │      CLI ↔ Daemon ↔ Wide Model ↔ MCP tools
  │
M5  ─── Bootable CognitiveOS ISO on QEMU            (Phase 5+6)
  │      "Start device → ask AI → AI does"
  │
M6  ─── Registry online, cpm install from it        (Phase 7)
  │
M7  ─── v0.1.0 release                             (ALL PHASES)
```

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| llama.cpp doesn't cross-compile for Alpine on ARM | Medium | High | Fall back to cloud inference for ARM targets; use pre-built llama.cpp binaries |
| Bubble Tea TUI flickers during framebuffer transitions | Medium | Medium | Use double-buffering; test on real hardware early |
| Wireless drivers missing in custom kernel | Medium | Medium | Start with Ethernet-only; add Wi-Fi drivers iteratively |
| cgroup isolation breaks MCP servers that need /dev access | Low | Medium | White-list specific /dev entries per server type |
| .cgp format too rigid for complex skills | Low | Low | Design with extensions in mind; cognitive.json supports `extras` field |
| Performance on RPi Zero too slow for real-time voice | High | Medium | Offload voice processing to Wide Model server; keep Raw Model minimal |
| Registry becomes single point of failure | Low | Low | Design for multiple registries; support offline .cgp files |
