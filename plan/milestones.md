# Milestones

## M0 — Foundation Complete
- [x] All product-specs documents written (vision, architecture, all API specs, schemas)
- [x] All 10 CognitiveOS-Project repos created on GitHub
- [x] Implementation plan documented

## M1 — Core Package Manager (Initial) ✅ COMPLETE
- [x] `cpm install` works for local .cgp files
- [x] `cpm list`, `cpm info`, `cpm remove` functional
- [x] `cpm verify` validates archives against cognitive schema
- [x] Hardware audit rejects oversized patches
- [x] `cpm init` creates skeleton, `cpm init --template gguf-model` for model publishers
- [x] `cpm search` queries registry, `cpm publish` registers checksums
- [x] `cpm download-weights` downloads from HuggingFace Hub
- [x] Universal Protocol Router: 7 protocol handlers (local, registry, npm, bun, deno, git, ghr, URL)
- [x] **Demo:** `cpm install ./sample.cgp` on Alpine Linux

## M1b — CPM Spec Compliance ✅ COMPLETE
- [x] **1b.1:** Dependency resolution during install (recursive transitive deps)
- [x] **1b.1:** Notary checksum verification on install (verify SHA-256 against registry record)
- [x] **1b.1:** Search filters (`--license`, `--min-ram`) passed to registry API
- [x] **1b.2:** Registry client endpoints: `GetVersions`, `GetDependencies`, `Unlock`
- [x] **1b.2:** Registry download follows 302 redirect (notary proxy)
- [x] **1b.2:** Version status awareness (reject deprecated/buggy; show in list/info)
- [x] **1b.3:** Standardized `ERROR:<code>:<message>` error format
- [x] **1b.3:** `--yes` flag for confirmation prompts
- [x] **1b.3:** `cpm update` uses universal resolver (not just registry)
- [x] **1b.3:** Search `--capability`, `--exact` filters
- [x] **1b.4:** Init templates (prompt-only, mcp-bridge, firmware, full)
- [x] **1b.4:** `info` shows source, checksum, registry status
- [x] **1b.4:** `verify` checks referenced dependencies
- [x] **1b.4:** `publish --scope` and `--visibility`

## M2 — Hardware Bridges ✅ COMPLETE
- [x] display-mcp renders images to framebuffer
- [x] audio-mcp plays audio and captures microphone
- [x] network-mcp scans and connects to Wi-Fi
- [x] gpio-mcp reads and writes pins
- [x] serial-mcp sends and receives over UART
- [x] package-mcp wraps cpm for AI-initiated package management
- [x] Shared MCP JSON-RPC 2.0 framework in internal/mcp
- [x] **Demo:** "Show me photo.jpg" → image appears on screen

## M2b — Bridge Spec Compliance ✅ COMPLETE
- [x] **2b.1:** Error envelope format (`ERROR:<CODE>:<message>` across all bridges)
- [x] **2b.1:** `outputSchema` in tool metadata for structured tools
- [x] **2b.1:** `--version` flag on all 6 bridge binaries
- [x] **2b.1:** Network connect open-network fix (no `psk=""` for unencrypted)
- [x] **2b.1:** Serial list_ports structured output with description/vendor
- [x] **2b.1:** Display render_image `fit` parameter
- [x] **2b.2:** Spec-aligned error codes per bridge (E_BUSY, E_NO_DEVICE, etc.)
- [ ] **2b.2:** Logging to `/cognitiveos/logs/bridges/<name>.log`
- [ ] **2b.2:** Resource cost annotations on tools

## M3 — Inference Engine
- [ ] `POST /api/generate` produces completions from Raw Model
- [ ] `GET /cognitiveos/status` reports resource usage
- [ ] Resource negotiation with cognitiveosd
- [ ] Idle timeout unloads model automatically
- [ ] Model swap works (unload A, load B)
- [ ] **Demo:** Raw Model responds to a query

## M4 — Integrated System
- [ ] cognitiveosd runs as PID 1 or supervised daemon
- [ ] cli connects to daemon socket
- [ ] Input flows: cli → daemon → Wide Model → daemon → cli
- [ ] System codes: wake, idle, security, reset working
- [ ] MCP servers spawn and register automatically
- [ ] Tool routing: Wide Model → daemon → MCP server → daemon → Wide Model
- [ ] Hardware audit runs on interval
- [ ] **Demo:** End-to-end: "Show me photo" → AI calls display-mcp → photo appears

## M5 — Bootable ISO
- [ ] `make iso` produces bootable x86_64 ISO
- [ ] `make rpi` produces Raspberry Pi SD card image
- [ ] Boot on QEMU → CLI appears → "CognitiveOS ready"
- [ ] Raw Model loads at boot
- [ ] **Demo:** Boot CognitiveOS in QEMU, type a command, get a response

## M6 — Registry Ecosystem (Notary Proxy)
- [x] `GET /v1/search` returns results
- [x] `GET /v1/patches/{name}/{version}` returns metadata with sha256 + download_url
- [x] `GET /v1/patches/{name}/{version}/download` redirects to canonical download URL
- [x] `POST /v1/patches` JSON-only publish with manifest + sha256 + download_url
- [x] `PUT /v1/patches/{name}/{version}` publish new version
- [x] A1-A10 publish-time validation (manifest, schema, cycles, file refs, hardware bounds, URLs)
- [x] Scoped token auth (publish/admin)
- [x] File-backed persistence (survives restarts)
- [x] `PATCH .../status`, `POST .../validate`, `GET .../dependencies` endpoints
- [x] `cpm publish ./skill.cgp --download-url <url>` registers in registry
- [x] `cpm install <name>` downloads via registry redirect
- [x] `cpm init my-skill` creates valid .cgp skeleton
- [ ] SQLite backend (upgrade from file-backed JSON)
- [ ] Full unlock code flow end-to-end
- [ ] **Demo:** `cpm search photo` → `cpm install photo-viewer` → AI can show photos

## M7 — v0.1.0 Release
- [ ] All repos tagged `v0.1.0`
- [ ] Bootable ISO published to GitHub Releases
- [ ] RPi image published
- [ ] Registry running at registry.cognitive-os.org
- [ ] Release notes written
