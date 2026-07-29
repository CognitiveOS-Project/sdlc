# Boot / Startup / Process Lifecycle Implementation Plan

Version: 1.0.0-draft

## Overview

This document defines the implementation plan for fixing the CognitiveOS boot/startup chain. It translates the technical analysis in [product-specs/boot-startup-analysis.md](https://github.com/CognitiveOS-Project/product-specs/blob/main/specs/boot-startup-analysis.md) into actionable phases with clear deliverables, dependencies, and verification criteria.

## Current State

The boot chain is **functional**. Both ISO and Docker deployments start successfully with `coginit` as unified PID 1:

- `coginit` replaces the fragile shell-based init chain (OpenRC scripts + tini + entrypoint.sh)
- Processes start in dependency order: cograw → coginfer → cognitiveosd → CLI
- Socket/HTTP readiness checks before proceeding
- Process supervision with auto-restart on crash (500ms delay)
- config.toml is read by both coginit (`DefaultModelPath()`) and cognitiveosd (`FromTOML()`)
- cpm-boot-deps and cpm-runtime-deps run by coginit (`installDependencies()`)
- Daemon still fatally exits if cograw is not already running (by design — security requirement)
- CLI Messages channel properly closed in `Close()`, reader handles zero-value shutdown

**Status:** ✅ All deployment methods (ISO, Docker, bare-metal) reach a working "CognitiveOS ready" state.

### Binary Build Chain (Working)

The build pipeline correctly compiles and installs all 5 binaries. The gap is in the init system, not the build system.

| Binary | Source Repo | Build | Install Path | Init Mechanism |
|--------|------------|-------|-------------|----------------|
| cograw | inference | ✅ `make build` | `/usr/local/bin/cograw` | ✅ Started by coginit (`startCograw()` in engine.go) |
| coginfer | inference | ✅ `make build` | `/usr/local/bin/coginfer` | ✅ Started by coginit (`startCoginfer()` in engine.go) |
| cognitiveosd | cognitiveosd | ✅ `make build` | `/usr/local/bin/cognitiveosd` | ✅ Started by coginit (`startCognitiveosd()` in engine.go) |
| cognitiveos-cli | cli | ✅ `make build` | `/usr/local/bin/cognitiveos-cli` | ✅ TUI supervision loop (bare-metal) / `syscall.Exec` (Docker) |
| cpm | cpm | ✅ `make build` | `/usr/local/bin/cpm` | ✅ Called by coginit (`installDependencies()`) |

**Build flow:** `build-binaries.sh` iterates repos in dependency order (`cpm → inference → core-mcp-bridges → cognitiveosd → cli`), runs `make build` for each, copies `*/build/bin/*` into `distro/build/bin/`. `build-overlay.sh` then copies everything to `overlay/usr/local/bin/`. For ISO: `genapkovl` tars the overlay. For Docker: `COPY --from=builder /out/ /`.

**Key insight:** 5 of 5 binaries are correctly compiled and installed. 5 of 5 have proper init mechanisms via coginit. All services start and are supervised by a single compiled Go binary.

## Scope

### In Scope

1. ISO boot chain fix (inittab + OpenRC init scripts + genapkovl registration)
2. Docker boot chain fix (tini + entrypoint wrapper)
3. TOML config reading (cognitiveosd)
4. Reliability fixes (coginfer signals, CLI reconnection, config.Derive(), MCPBinDir)

### Out of Scope (Future Work)

- MCU ruleset mode for cograw (no code exists)
- Daemon spawning cograw (init system approach chosen instead)
- Wide model Unix socket (coginfer remains HTTP-only)
- config.toml sections for network/audio/display (belong to MCP components)
- registries.toml reading (future CPM work)
- Process supervision beyond OpenRC (e.g., systemd, s6)

## Implementation Phases

**Note:** The original plan (Phases 1-2 below) was designed around OpenRC init scripts + tini + shell entrypoint. During implementation, this approach was replaced by a single compiled Go binary (`coginit`) serving as unified PID 1 — see Phase 6b in `implementation-plan.md`. The phases below document the original design intent; the actual implementation follows the coginit architecture described in Phase 6b. All goals are met via coginit.

### Phase 1: ISO Boot Chain Fix ✅ SUPERSEDED BY coginit

**Goal:** System boots to a working TUI on bare-metal or VM.

**Actual implementation:** Instead of 7 OpenRC scripts + genapkovl registration, a single `coginit` binary (Go, statically compiled) handles all CognitiveOS services:
- Bare-metal: started by inittab on tty1/ttyS0 via `/usr/local/bin/coginit --bare-metal`
- Mounts virtual filesystems, configures loopback, starts engines in order
- Waits for socket/HTTP readiness, supervises processes with auto-restart
- Runs cpm boot/runtime dependencies via `installDependencies()`

**Results:**
- ✅ inittab contains `::sysinit:`, `::wait:`, and `::shutdown:` lines with OpenRC stages
- ✅ No OpenRC init scripts needed — coginit handles all CognitiveOS services
- ✅ `cograw` starts and opens `raw.sock` before cognitiveosd
- ✅ `cognitiveosd` connects to `raw.sock` without fatal exit
- ✅ CLI renders TUI and displays "CognitiveOS ready"
- ✅ Process supervision with auto-restart on crash (500ms delay)

### Phase 2: Docker Boot Chain Fix ✅ SUPERSEDED BY coginit

**Goal:** Docker container starts successfully with all three daemons running.

**Actual implementation:** Instead of tini + entrypoint shell script, `coginit` is used as PID 1 via `ENTRYPOINT ["/usr/local/bin/coginit"]`:
- No tini dependency needed — coginit handles zombie reaping and signal forwarding
- No shell entrypoint — coginit starts engines, waits for readiness, then `syscall.Exec` into CLI
- Signal handling: `docker stop` → SIGTERM to coginit → forward to all children → clean exit

**Results:**
- ✅ coginit is PID 1 (not tini, not CLI)
- ✅ All 3 daemons running before CLI exec
- ✅ Socket/HTTP readiness checks with appropriate timeouts
- ✅ `docker stop` triggers graceful shutdown
- ✅ No shell scripts — single compiled binary for init

### Phase 3: TOML Config Reading ✅ COMPLETE

**Goal:** cognitiveosd reads `config.toml` at startup, aligning code with specs.

**Status:** Fully implemented. Additionally, coginit now reads `config.toml` for the raw model path.

**Deliverables:**

| # | Deliverable | File | Description | Status |
|---|------------|------|-------------|--------|
| 3.1 | Add TOML dependency | `cognitiveosd/go.mod` | `github.com/BurntSushi/toml` (zero transitive deps) | ✅ Done |
| 3.2 | FromTOML function | `cognitiveosd/internal/config/config.go` | Read daemon-relevant TOML sections into Config struct | ✅ Done |
| 3.3 | Wire into startup | `cognitiveosd/cmd/cognitiveosd/main.go` | Call FromTOML between Default and FromEnv | ✅ Done |
| 3.4 | Fix config.toml | `overlay/etc/cognitiveos/config.toml` | Change `backend = "cli"` to `backend = "cgo"` | ✅ Done |
| 3.5 | Coginit reads config.toml | `coginit/internal/coginit/config.go` | `DefaultModelPath()` reads `[raw_model].model` with precedence: `--model` flag > env > config.toml > default | ✅ Done |

**Config loading chain:**
```
config.Default → FromTOML("/etc/cognitiveos/config.toml") → FromEnv() → flags → Derive()
```

Coginit follows the same chain for model path:
```
default → config.toml [raw_model].model → env COGNITIVEOS_RAW_MODEL_PATH → --model flag
```

**Verification results:**
- ✅ `go.mod` contains `github.com/BurntSushi/toml`
- ✅ `FromTOML()` reads all daemon-relevant sections
- ✅ TOML values override defaults but are overridden by env vars and flags
- ✅ `Derive()` remains last in the chain, respects `SocketPathExplicit` flag
- ✅ `DefaultModelPath()` in coginit reads `[raw_model].model` from config.toml
- ✅ `config.toml` has `backend = "cgo"` (not "cli")
- ✅ Unit tests pass

### Phase 4: Reliability Fixes ✅ COMPLETE

**Goal:** Fix known bugs that affect boot reliability.

**Status:** All items verified in code (no code changes needed — items 4.1-4.3 were already implemented but undocumented; items 4.4-4.5 were fixed in prior sessions).

**Deliverables:**

| # | Deliverable | File | Description | Status |
|---|------------|------|-------------|--------|
| 4.1 | **cograw `--backend` flag** | `inference/cmd/cograw/main.go` | `--backend` flag already present at line 249 (`backend := flag.String("backend", "cgo", ...)`). Used at line 265 (`rm := NewRawModel(newBackend(*backend))`). | ✅ Already existed in code |
| 4.2 | coginfer signal handling | `inference/cmd/coginfer/main.go` | `http.Server` + signal.Notify + `Shutdown(ctx)` with 30s timeout already present at lines 62-83. | ✅ Already existed in code |
| 4.3 | CLI reconnection fix | `cli/internal/client/client.go` | `Close()` at line 63-71 closes both `c.done` and `c.Messages` inside `closeOnce.Do()`. | ✅ Already existed in code |
| 4.4 | config.Derive() fix | `cognitiveosd/internal/config/config.go` | `SocketPathExplicit` bool added. `Derive()` skips `SocketPath` overwrite when explicitly set. | ✅ Done |
| 4.5 | MCPBinDir fix | `cognitiveosd/internal/config/config.go` | Default changed from `/cognitiveos/bin` to `/usr/local/lib/cognitiveos/bridges`. | ✅ Done |

**Design decisions:**

| Decision | Rationale |
|----------|-----------|
| Add `--backend` to cograw | cograw currently uses compile-time build tags for backend selection. Adding a runtime flag enables Docker degraded mode (mock backend when model file is missing) and testing without GGUF. Pattern already exists in coginfer. |
| Replace `http.ListenAndServe` | Current code uses bare `http.ListenAndServe` with zero signal handling. SIGTERM kills mid-request and model is not unloaded. Must expose `*http.Server` for `Shutdown()` support. |
| Close `Messages` in `Close()` | Current `listenCmd` does `for env := range conn.Messages` which blocks forever after connection drop because `Messages` channel is never closed. `reconnectMsg{}` is unreachable. |
| Track `socketPathExplicit` | `Derive()` unconditionally overwrites `SocketPath` from `RunDir`, making `COGNITIVEOS_SOCKET` env and `--socket` flag dead code. Track whether socket was explicitly set. |

**Verification criteria:**
- [ ] `cograw --backend mock` starts without a GGUF model file
- [ ] `cograw --backend cgo` starts with GGUF model (production behavior unchanged)
- [ ] coginfer exits cleanly on SIGTERM (model unloaded, log message)
- [ ] CLI reconnects after daemon restart (Messages channel closed properly)
- [ ] `--socket /custom/path.sock` is preserved through Derive()
- [ ] `COGNITIVEOS_SOCKET=/custom/path.sock` is preserved through Derive()
- [ ] MCPBinDir default matches actual bridge installation path
- [ ] All unit tests pass in affected repos

**Risk:** Low. Each fix is isolated and well-understood.

**Estimated effort:** 3-4 hours total.

## Implementation Order (As Executed)

The actual implementation took a different path than originally planned:

```
Phase 6b (coginit)     ──── created unified PID 1 replacing Phases 1-2
Phase 3 (TOML Config)  ──── implemented in cognitiveosd then extended to coginit
Phase 4 (Reliability)  ──── verified in code, docs updated to match reality
```

Instead of building on OpenRC + tini + shell scripts, we created `coginit` as a compiled Go binary that serves as unified PID 1 for both Docker and bare-metal, handling: process supervision, signal handling, service ordering, config parsing, and TUI lifecycle management.

## Cross-Repo Impact

| Phase | Repos Affected | Changes | Status |
|-------|---------------|---------|--------|
| Phase 1 (ISO Boot) | `cognitiveos-alpine-distro`, `coginit` | inittab update, coginit handles all CognitiveOS services | ✅ Superseded by coginit |
| Phase 2 (Docker Boot) | `cognitiveos-alpine-distro`, `coginit` | Docker ENTRYPOINT → coginit, no tini needed | ✅ Superseded by coginit |
| Phase 3 (TOML Config) | `cognitiveosd`, `coginit` | `config.go` (FromTOML), `coginit/config.go` (DefaultModelPath) | ✅ Done |
| Phase 4 (Reliability) | `inference`, `cli`, `cognitiveosd` | Verified in code: --backend, signals, Messages close, Derive(), MCPBinDir | ✅ Done |

**Build chain dependency:** All phases depend on the existing build pipeline (`build-binaries.sh` → `build-overlay.sh` → ISO/Docker packaging). No changes to the build pipeline are needed. The runtime init gap was resolved by coginit, a compiled Go binary with zero external dependencies (beyond BurntSushi/toml for config parsing).

## Design Decisions (Resolved)

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| Init architecture | **`coginit` unified PID 1** (not OpenRC scripts + tini) | Single compiled Go binary replaces fragile shell chain. Handles Docker and bare-metal with same code. Zero shell quoting bugs, CRLF issues, or missing commands. |
| Docker missing model | Option A — degraded mode | cograw detects missing GGUF, `--backend mock` fallback, system operates with guardrail active but no inference. |
| cograw backend selection | `--backend` flag (runtime, not compile-time) | Runtime flag enables degraded mode and testing. Pattern exists in coginfer. |
| Service supervision | coginit goroutine (500ms restart) | Instead of OpenRC respawn or Docker --restart. Detects exit via `cmd.Wait()`, restarts in goroutine. |
| Config.toml priority | `--model` > env > config.toml > default | Coginit's `DefaultModelPath()` follows the same precedence chain as cognitiveosd's `FromEnv()`. |

## Testing Strategy

### Unit Tests

- Phase 3: `go test ./internal/config/...` in cognitiveosd
- Phase 4: `go test ./...` in inference, cli, cognitiveosd

### Integration Tests

- Phase 1: Boot ISO in QEMU, verify all services start in order
- Phase 2: `docker build` + `docker run`, verify all daemons running
- Phase 3: Start daemon with custom TOML, verify values applied
- Phase 4: Signal handling test (SIGTERM → clean exit), reconnection test

### Hardware Tests

- Phase 1: Boot on Raspberry Pi (edge-armv7), verify TUI appears
- Phase 1: Boot on x86_64 VM, verify TUI appears

## Risk Register (Resolved)

| Risk | Phase | Likelihood | Impact | Mitigation | Outcome |
|------|-------|-----------|--------|------------|---------|
| Go binary complexity for PID 1 | coginit | Medium | Medium | Use Go stdlib only; add BurntSushi/toml for config (zero transitive deps) | ✅ No issues. Static binary, no runtime deps. |
| TOML library conflicts with Go version | 3 | Low | Low | BurntSushi/toml has zero deps; test with `go mod tidy` | ✅ Works with Go 1.26. |
| cograw model missing in Docker | 2 | Medium | Medium | cograw falls back to `--backend mock` when GGUF missing | ✅ Degraded mode functional. |
| Derive() fix breaks other derived paths | 4 | Low | Medium | Only skip SocketPath override; all other derivations unchanged | ✅ Fixed with `SocketPathExplicit` bool. |
