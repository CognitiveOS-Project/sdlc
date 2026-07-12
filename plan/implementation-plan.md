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
| `cognitiveos-alpine-distro` | Distribution | Shell/Docker | Alpine image builder |
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

cognitiveos-alpine-distro ───── depends on all built binaries
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

### Phase 1: Core Package Manager — Initial Implementation ✅ COMPLETE

**Repos:** `cpm`

All tasks in the initial Phase 1 are implemented and merged to `main`. The CPM CLI supports `init`, `install` (7 protocol handlers: local, registry, npm, bun, deno, git, ghr, URL), `remove`, `list`, `info`, `verify`, `search`, `update`, `publish`, and `download-weights`.

### Phase 1b: CPM Gaps — Spec Compliance & Integration

**Goal:** Close gaps between the cpm-spec.md, dependency-validation.md, registry-api.md specs and the implementation. Four sub-phases:

#### Phase 1b.1 — Core Install Completeness

| Gap | Task | Est. effort |
|-----|------|-------------|
| Dependency resolution | Recursively install transitive `dependencies` during `cpm install` using `dep.Resolve()` | Medium |
| Notary checksum verification | Before install, fetch registry metadata to get recorded SHA-256, verify downloaded archive against it | Medium |
| Search filters pass-through | Pass `--license`, `--min-ram` flags to registry `Search` API; update `registry.Client.Search()` signature | Small |

#### Phase 1b.2 — Registry Protocol Completeness

| Gap | Task | Est. effort |
|-----|------|-------------|
| Missing registry endpoints | Add `GetVersions(name)`, `GetDependencies(name)`, `Unlock(name, version, code)` to registry client | Medium |
| 302 redirect handling | `Download()` should follow HTTP 302 to canonical URL (notary proxy pattern) | Small |
| Version status awareness | Check `active/deprecated/buggy` status before install (reject deprecated/buggy); show in `list`/`info` | Medium |

#### Phase 1b.3 — Polish & Conformance

| Gap | Task | Est. effort |
|-----|------|-------------|
| Error format | Standardized `ERROR:<code>:<message>` error output across all commands | Small |
| `--yes` flag | Implement confirmation prompts for destructive ops; `--yes` skips them | Small |
| Update via resolver | `cpm update` should use the universal resolver, not just registry (handle git/npm/deno sources) | Medium |
| Search `--capability` / `--exact` | Additional search filters from spec | Small |

#### Phase 1b.4 — Feature Completeness

| Gap | Task | Est. effort |
|-----|------|-------------|
| Init templates | Add `prompt-only`, `mcp-bridge`, `firmware`, `full` templates to `cpm init --template` | Medium |
| `info` enhancements | Show source URL, checksum, registry status, dependency tree | Small |
| `verify` dependency check | Verify referenced dependencies exist in archive | Small |
| `publish --scope` / `--visibility` | Support scoped packages and visibility flags | Small |

#### Phase 1b.5 — Packaging Enhancements

| Gap | Task | Est. effort | Status |
|-----|------|-------------|--------|
| Manifest-based packing | Implement `--manifest` flag in `cpm pack` with auto-detection and merge logic | Small | ✅ Done |
| Component manifests | Create `cognitive.json` for all core components (bridges, daemon, cli, inference) | Small | ✅ Done |
| Makefile integration | Update component Makefiles to use manifest-based packaging | Small | ✅ Done |

### Phase 2: Hardware Bridges — Initial Implementation ✅ COMPLETE

**Repos:** `core-mcp-bridges`

All six bridges (display, audio, network, gpio, serial, package) are implemented with core functionality using the shared `internal/mcp` JSON-RPC 2.0 framework.

### Phase 2b: Bridge Spec Compliance

**Goal:** Close gaps between the MCP conventions spec, bridge JSON schemas, and the implementation.

| Gap | Task | Est. effort |
|-----|------|-------------|
| Error envelope format | Change `E_<CODE>: message` to spec-standard `ERROR:<CODE>: <message>` across all 6 bridges | Small |
| `outputSchema` in tool metadata | Add `outputSchema` to tools that return structured data (list/interfaces/status tools) | Small |
| `--version` flag | Add `--version` flag to all 6 bridge binaries per MCP conventions spec | Small |
| Network connect open-network bug | Fix wpa_supplicant config to not write `psk=""` when no password | Small |
| Serial list_ports structured output | Add description/vendor/product to structured port list response | Small |
| Display render_image `fit` param | Add `fit` parameter support (fill/fit/stretch) | Small |
| Spec-aligned error codes per bridge | Add missing error codes: `E_BUSY`, `E_UNSUPPORTED_FORMAT`, `E_NO_DEVICE`, `E_SESSION_NOT_FOUND`, etc. | Medium |
| Logging path per spec | Route logs to `/cognitiveos/logs/bridges/<name>.log` instead of stderr | Small |
| Resource cost annotations | Add optional `cost` annotations to tool definitions | Small |

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

### Phase 3b: Inference Spec Compliance ✅ COMPLETE

**Goal:** Close gaps between the inference-api.md spec, raw-model.md spec, and the implementation.

| Gap | Task | Est. effort | Status |
|-----|------|-------------|--------|
| Idle timeout | Implement 5-minute idle timer that auto-unloads the Wide Model | Small | ✅ |
| DELETE /api/delete response | Return `ram_freed_mb` in response body per spec | Small | ✅ |
| GET /api/ps fields | Populate `processor` (CPU/CPU+GPU), `gpu_layers`, `context_usage_percent` from actual backend state | Small | ✅ |
| Spec-aligned error codes | Use `E_MODEL_NOT_FOUND`, `E_INVALID_PARAMS`, `E_INTERNAL` in HTTP handlers | Small | ✅ |
| Health `last_error` field | Track and expose last error in health endpoint response | Small | ✅ |
| Resource negotiation reads `/proc/meminfo` | Replace hardcoded `availableRAM=4096` with real memory reading | Small | ✅ |
| cograw `--version` flag | Add `--version` flag to match bridge convention | Small | ✅ |
| cograw cooldown timing fix | Fix `isCooldown()` to use correct 5-minute lockout per spec | Small | ✅ |
| Status endpoint raw model info | Query raw socket to populate `raw_model.loaded` and `ram_usage_mb` | Medium | ❌ deferred |

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

### Phase 4b: Daemon Spec Compliance

**Repos:** `cognitiveosd`

**Goal:** Bring the daemon into full compliance with `cognitiveosd-api.md`.

| Task | Dependencies | Est. effort | Status |
|------|-------------|-------------|--------|
| Bridge error format: MCP Invoke handles `isError:true` in result | Phase 2b bridge compliance | Small | ✅ Done |
| UUID v4 generation for message envelope IDs | cognitiveosd-api | Small | ✅ Done |
| Shutdown stops accepting new messages (`E_SHUTDOWN` guard) | cognitiveosd-api | Small | ✅ Done |
| `/cognitiveos/run/` unmount in shutdown sequence | cognitiveosd-api | Small | ✅ Done |
| Wide model status tracking (loading/unloaded/loaded) | cognitiveosd-api | Small | ✅ Done |
| Spec-aligned error codes (`E_INSUFFICIENT_RESOURCES`, `E_INTERNAL`, `E_SHUTDOWN`, `E_PACKAGE_*`) | cognitiveosd-api | Small | ✅ Done |
| CPU audit from `/proc/cpuinfo` + `/proc/loadavg` | cognitiveosd-api | Small | ✅ Done |
| NPU audit from `/sys/class/accelerator` + `/dev/npu*` | cognitiveosd-api | Small | ✅ Done |

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

### Phase 5b: CLI Spec Compliance

**Repos:** `cli`

**Goal:** Bring the CLI into full compliance with `cli-spec.md`.

| Task | Dependencies | Est. effort | Status |
|------|-------------|-------------|--------|
| Ctrl+D sends `system_code idle` (shutdown confirmation) | cli-spec | Small | ✅ Done |
| Ctrl+Alt+S sends `system_code security` (immediate, any state) | cli-spec | Small | ✅ Done |
| Spinner uses dots cycling (`.`, `..`, `...`) per spec | cli-spec | Small | ✅ Done |
| Processing cancel sends cancellation to daemon | cli-spec | Small | ✅ Done |
| Output rendering: code blocks, lists, tables, URLs | cli-spec | Medium | ✅ Done |
| Media mode — `content_type:media` transitions to overlay state | cli-spec | Medium | ✅ Done |
| History navigation in responding mode (Up/Down) | cli-spec | Small | ✅ Done |
| Voice input waveform animation | cli-spec | Medium | Pending |
| Shift+Up/Down scrolling for long output | cli-spec | Medium | Pending |
| Tab action button cycling in responding mode | cli-spec | Medium | Pending |

### Phase 6: Distribution Image

**Repos:** `cognitiveos-alpine-distro`

**Goal:** Bootable Alpine Linux image with all CognitiveOS components baked in.

| Task | Dependencies | Est. effort | Status |
|------|-------------|-------------|--------|
| Overlay assembly script | All above binaries compiled | Medium | ✅ Done |
| Alpine mkimage ISO generation | distro-build-spec | Medium | ✅ Done |
| Alpine mkimage RPi SD card generation | distro-build-spec | Medium | ✅ Done |
| Custom inittab integration | None | Small | ✅ Done |
| First-boot setup automation | None | Small | ✅ Done |
| Docker-based cross-compilation environment | None | Medium | ✅ Done |
| Makefile with iso/rpi/clean targets | None | Small | ✅ Done |
| Image signing and checksum generation | None | Small | ✅ Done |
| Binary naming — repo-owned (coginfer, bridges/) | inference, core-mcp-bridges | Small | ✅ Done |
| `cpm download-weights` picks smallest by size | cpm | Small | ✅ Done |
| Alpine packages: fbv, fbi, gpiod-tools | None | Small | ✅ Done |
| VERSION file + spec image naming | None | Small | ✅ Done |
| Overlay models/ dirs + image-manifest.json | None | Small | ✅ Done |
| Model download step in build-overlay.sh | cpm download-weights | Small | ✅ Done |

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

### Phase 8: Autonomous Package Management

**Repos:** `core-mcp-bridges`, `cognitiveosd`, `inference`, `product-specs`

**Goal:** The Wide Model can autonomously discover, install, and remove packages in response to human requests, with every operation validated by the Raw Model.

| Task | Dependencies | Est. effort | Status |
|------|-------------|-------------|--------|
| ADR-004: Package Manager MCP Bridge decision record | None | Small | ✅ Done |
| `product-specs/specs/base-prompt.md` — daemon-level system prompt | None | Small | Pending |
| `cognitiveos.package.*` domain in mcp-conventions.md | None | Small | Pending |
| `validate_package_request` RPC in raw-model.md spec | None | Small | Pending |
| Validation-hook section in cognitiveosd-api.md | None | Small | Pending |
| `package-mcp` bridge in core-mcp-bridges/ | MCP server library | Medium | Pending |
| MCP validation hook in cognitiveosd mcp_lifecycle.go | cognitiveosd-api spec | Small | Pending |
| `validate_package_request` handler in cograw | raw-model.md spec | Small | Pending |
| `ValidatePackageRequest` method in raw_client.go | None | Small | Pending |
| `package-mcp` in default MCPBridges config | None | Small | Pending |
| Base system prompt injection in daemon startup | None | Small | Pending |
| Tool validation wiring in handlers.go (toolLoop) | None | Small | Pending |

**Definition of done:**
- Wide Model calls `cognitiveos.package.search("photo viewer")` → daemon validates → package-mcp runs `cpm search`
- Wide Model calls `cognitiveos.package.install("photo-viewer")` → daemon validates via Raw Model → package-mcp runs `cpm install`
- Raw Model denies install if manifest contains `raw_model` field
- Raw Model enforces rate limit (5 ops / 5 min)
- Read-only ops (search/list/info) go through validation with reduced checks
- Base system prompt tells the Wide Model it can autonomously install capabilities
- All 6 package tools are registered and discoverable via `mcp.list_tools`

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
M5  ─── CLI boots, connects, sends/receives         (Phase 5)
      │      "Start device → ask AI → AI does"
      │
M5b ─── CLI spec compliance                         (Phase 5b)
      │      Ctrl+D/S, spinner dots, media mode, output formatting
      │
M6  ─── Distribution image builds                   (Phase 6)
      │      make iso, make rpi, boot to CLI
      │
M7  ─── Registry online, cpm install from it        (Phase 7)
  │
M8  ─── v0.1.0 release                             (ALL PHASES)
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
\n## System Dependencies Implementation Summary\n\nThe system-level dependency management is implemented as a deferred registration and installation system.\n\n### Architecture\n1. **Manifest Declaration**: CGP manifests declare system dependencies in `hardware_dependencies.packages` with a lifecycle stage (`build`, `boot`, `install`, `runtime`).\n2. **Registration**: During `cpm install`, dependencies are registered via `cpm register-dependencies`, writing a record to `/cognitiveos/lib/cpm/queue/<stage>/<patch_id>_<dep_id>.json`.\n3. **Installation**: Dependencies are installed via `cpm install-dependencies --stage <stage>`, which processes the queue and uses the declared package manager (e.g., `apk`).\n4. **Lifecycle Flow**:\n   - **Build Stage**: Handled by build scripts during image creation.\n   - **Boot Stage**: Handled by an OpenRC service (`cpm-boot-deps`) before the system daemon starts.\n   - **Install Stage**: Handled immediately by `cpm install` before the patch is extracted.\n   - **Runtime Stage**: Handled by an OpenRC service or the daemon on demand.\n\n### Key Components\n- **Queue**: Durable records in `/cognitiveos/lib/cpm/queue/` ensure dependencies survive reboots.\n- **Manager**: `cpm/internal/manager` abstracts package manager specifics (apk, npm, etc.).\n- **Idempotency**: The installer verifies package presence before attempting installation, allowing multiple patches to share dependencies.\n- **Safety**: The system separates base OS packages (curated in `packages.<class>-<arch>`) from CGP-specific dependencies.
