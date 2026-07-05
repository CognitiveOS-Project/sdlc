# Milestones

## M0 — Foundation Complete
- [x] All product-specs documents written (vision, architecture, all API specs, schemas)
- [x] All 10 CognitiveOS-Project repos created on GitHub
- [x] Implementation plan documented

## M1 — Core Package Manager
- [ ] `cpm install` works for local .cgp files
- [ ] `cpm list`, `cpm info`, `cpm remove` functional
- [ ] `cpm verify` validates archives against cognitive schema
- [ ] Hardware audit rejects oversized patches
- [ ] **Demo:** `cpm install ./sample.cgp` on Alpine Linux

## M2 — Hardware Bridges
- [ ] display-mcp renders images to framebuffer
- [ ] audio-mcp plays audio and captures microphone
- [ ] network-mcp scans and connects to Wi-Fi
- [ ] gpio-mcp reads and writes pins
- [ ] serial-mcp sends and receives over UART
- [ ] **Demo:** "Show me photo.jpg" → image appears on screen

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
