# Boot / Startup / Process Lifecycle Implementation Plan

Version: 1.0.0-draft

## Overview

This document defines the implementation plan for fixing the CognitiveOS boot/startup chain. It translates the technical analysis in [product-specs/boot-startup-analysis.md](https://github.com/CognitiveOS-Project/product-specs/blob/main/specs/boot-startup-analysis.md) into actionable phases with clear deliverables, dependencies, and verification criteria.

## Current State

The boot chain is **non-functional**. Neither ISO nor Docker deployments can start successfully:

- Overlay inittab disables OpenRC entirely (no `::sysinit:`, `::wait:`, `::shutdown:` directives)
- No OpenRC init scripts exist for cograw, coginfer, or cognitiveosd
- Docker containers have no init system (cognitiveos-cli is PID 1)
- config.toml is not read by any code
- cpm-boot-deps and cpm-runtime-deps scripts exist but never execute
- Daemon fatally exits if cograw is not already running
- CLI has a reconnection bug (Messages channel never closed)

**Impact:** No deployment method (ISO, Docker, bare-metal) can reach a working "CognitiveOS ready" state.

### Binary Build Chain (Working)

The build pipeline correctly compiles and installs all 5 binaries. The gap is in the init system, not the build system.

| Binary | Source Repo | Build | Install Path | Init Mechanism |
|--------|------------|-------|-------------|----------------|
| cograw | inference | ✅ `make build` | `/usr/local/bin/cograw` | ❌ No init script |
| coginfer | inference | ✅ `make build` | `/usr/local/bin/coginfer` | ❌ No init script |
| cognitiveosd | cognitiveosd | ✅ `make build` | `/usr/local/bin/cognitiveosd` | ⚠️ CLI spawns (fire-and-forget) |
| cognitiveos-cli | cli | ✅ `make build` | `/usr/local/bin/cognitiveos-cli` | ✅ inittab respawn |
| cpm | cpm | ✅ `make build` | `/usr/local/bin/cpm` | ✅ OpenRC init scripts |

**Build flow:** `build-binaries.sh` iterates repos in dependency order (`cpm → inference → core-mcp-bridges → cognitiveosd → cli`), runs `make build` for each, copies `*/build/bin/*` into `distro/build/bin/`. `build-overlay.sh` then copies everything to `overlay/usr/local/bin/`. For ISO: `genapkovl` tars the overlay. For Docker: `COPY --from=builder /out/ /`.

**Key insight:** 5 of 5 binaries are correctly compiled and installed. 2 of 5 have proper init mechanisms. 3 of 5 are never started by the system.

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

### Phase 1: ISO Boot Chain Fix

**Goal:** System boots to a working TUI on bare-metal or VM.

**Dependencies:** None — this is the highest-priority, zero-dependency phase.

**Deliverables:**

| # | Deliverable | File | Description |
|---|------------|------|-------------|
| 1.1 | Fixed inittab | `overlay/etc/inittab` | Add OpenRC sysinit/boot/default/shutdown stages |
| 1.2 | cograw init script | `overlay/etc/init.d/cograw` | OpenRC script: start cograw with `--model` flag |
| 1.3 | coginfer init script | `overlay/etc/init.d/coginfer` | OpenRC script: start coginfer with `--backend cgo` |
| 1.4 | cognitiveosd init script | `overlay/etc/init.d/cognitiveosd` | OpenRC script: depends on cograw, before cpm-runtime-deps |
| 1.5 | genapkovl update | `scripts/genapkovl-cognitiveos.sh` | Register all 5 CognitiveOS services in `default` runlevel |
| 1.6 | cpm-boot-deps registration | `scripts/genapkovl-cognitiveos.sh` | Add `rc_add cpm-boot-deps default` |
| 1.7 | cpm-runtime-deps registration | `scripts/genapkovl-cognitiveos.sh` | Add `rc_add cpm-runtime-deps default` |

**Dependency chain after fix:**
```
cograw → coginfer → cpm-boot-deps → cognitiveosd → cpm-runtime-deps
```

**Verification criteria:**
- [ ] `inittab` contains `::sysinit:`, `::wait:`, and `::shutdown:` lines
- [ ] All 5 init scripts exist in `overlay/etc/init.d/` with correct `depend()` ordering
- [ ] `genapkovl-cognitiveos.sh` calls `rc_add` for all 5 services
- [ ] ISO build completes successfully
- [ ] Boot log shows OpenRC sysinit → boot → default stages executing
- [ ] `cograw` starts and opens `raw.sock` before cognitiveosd
- [ ] `cognitiveosd` connects to `raw.sock` without fatal exit
- [ ] CLI renders TUI and displays "CognitiveOS ready"

**Risk:** Low. All changes are shell scripts and config files. No Go code modifications.

**Estimated effort:** 1-2 hours.

### Phase 2: Docker Boot Chain Fix

**Goal:** Docker container starts successfully with all three daemons running.

**Dependencies:** Phase 1 (init scripts inform the entrypoint logic).

**Deliverables:**

| # | Deliverable | File | Description |
|---|------------|------|-------------|
| 2.1 | Entrypoint script | `docker/scripts/entrypoint.sh` | Wrapper: start cograw, coginfer, cognitiveosd, wait for sockets, exec CLI |
| 2.2 | tini installation | All 7 Dockerfiles | Add `apk add --no-cache tini` before ENTRYPOINT |
| 2.3 | ENTRYPOINT change | All 7 Dockerfiles | `ENTRYPOINT ["/sbin/tini", "--"]` + `CMD ["/usr/local/bin/cognitiveos-cli"]` |
| 2.4 | Package list update | `packages.*` files | Add `tini` to all 6 variant package lists |

**Entrypoint script logic:**
```sh
#!/bin/sh
set -e

mkdir -p /cognitiveos/run /cognitiveos/logs

# Start cograw (raw model guardrail)
/usr/local/bin/cograw --model /cognitiveos/models/raw/raw-model.gguf &
COGRAW_PID=$!

# Wait for raw.sock
for i in $(seq 1 30); do
    [ -S /cognitiveos/run/raw.sock ] && break
    sleep 0.2
done

# Start coginfer (wide model inference)
/usr/local/bin/coginfer --backend cgo --models /cognitiveos/models &
COGINFER_PID=$!

# Wait for HTTP :11434
for i in $(seq 1 30); do
    wget -q --spider http://127.0.0.1:11434/health 2>/dev/null && break
    sleep 0.2
done

# Start cognitiveosd (main daemon)
/usr/local/bin/cognitiveosd &
DAEMON_PID=$!

# Wait for daemon.sock
for i in $(seq 1 30); do
    [ -S /cognitiveos/run/daemon.sock ] && break
    sleep 0.2
done

# Exec CLI (replaces shell, becomes direct child of tini)
exec /usr/local/bin/cognitiveos-cli
```

**Verification criteria:**
- [ ] All 7 Dockerfiles use `tini` as PID 1
- [ ] `entrypoint.sh` starts all 3 daemons before CLI
- [ ] Socket wait loops have 30s timeout
- [ ] `docker build` completes for all variants
- [ ] `docker run` shows all 3 daemons in process list
- [ ] CLI renders TUI inside container
- [ ] `docker stop` sends SIGTERM → tini forwards to all children → clean shutdown

**Risk:** Medium. Entrypoint script must handle partial failures (e.g., cograw model missing, coginfer in mock mode).

**Estimated effort:** 2-3 hours.

### Phase 3: TOML Config Reading

**Goal:** cognitiveosd reads `config.toml` at startup, aligning code with specs.

**Dependencies:** None (independent of Phase 1 and 2).

**Deliverables:**

| # | Deliverable | File | Description |
|---|------------|------|-------------|
| 3.1 | Add TOML dependency | `cognitiveosd/go.mod` | `github.com/BurntSushi/toml` (zero transitive deps) |
| 3.2 | FromTOML function | `cognitiveosd/internal/config/config.go` | Read daemon-relevant TOML sections into Config struct |
| 3.3 | Wire into startup | `cognitiveosd/cmd/cognitiveosd/main.go` | Call FromTOML between Default and FromEnv |
| 3.4 | Fix config.toml | `overlay/etc/cognitiveos/config.toml` | Change `backend = "cli"` to `backend = "cgo"` |

**Config loading chain after fix:**
```
config.Default → FromTOML("/etc/cognitiveos/config.toml") → FromEnv() → flags → Derive()
```

**TOML sections to read:**

| Section | Keys | Go Config Field |
|---------|------|-----------------|
| `[daemon]` | `audit_interval_seconds` | `AuditInterval` |
| `[daemon]` | `mcp_bin_dir` | `MCPBinDir` |
| `[raw_model]` | `model` | `RawModelPath` |
| `[inference]` | `endpoint` | `InferenceURL` |
| `[inference]` | `idle_timeout_seconds` | New field (currently hardcoded) |

**Sections NOT read by daemon (belong to MCP components):**
- `[system]` — hostname, timezone, autologin
- `[network]` — network-mcp
- `[audio]` — audio-mcp
- `[display]` — display-mcp

**Verification criteria:**
- [ ] `go.mod` contains `github.com/BurntSushi/toml`
- [ ] `FromTOML()` reads all daemon-relevant sections
- [ ] TOML values override defaults but are overridden by env vars and flags
- [ ] `Derive()` remains last in the chain
- [ ] `config.toml` has `backend = "cgo"` (not "cli")
- [ ] Unit tests pass: `go test ./internal/config/...`
- [ ] Integration test: daemon starts with custom TOML values

**Risk:** Low. Single dependency, well-tested library, clear mapping.

**Estimated effort:** 1-2 hours.

### Phase 4: Reliability Fixes

**Goal:** Fix known bugs that affect boot reliability.

**Dependencies:** None (independent of other phases).

**Deliverables:**

| # | Deliverable | File | Description |
|---|------------|------|-------------|
| 4.1 | coginfer signal handling | `inference/cmd/coginfer/main.go` | Trap SIGTERM/SIGINT, call Unload(), exit gracefully |
| 4.2 | CLI reconnection fix | `cli/internal/client/client.go` | Close Messages channel in Close() |
| 4.3 | config.Derive() fix | `cognitiveosd/internal/config/config.go` | Don't overwrite SocketPath if --socket was explicitly set |
| 4.4 | MCPBinDir fix | `cognitiveosd/internal/config/config.go` | Change default from `/cognitiveos/bin` to `/usr/local/lib/cognitiveos/bridges` |
| 4.5 | cograw mock flag | `inference/cmd/cograw/main.go` | Add `--backend mock` flag for testing (skips os.Stat on model) |

**Verification criteria:**
- [ ] coginfer exits cleanly on SIGTERM (model unloaded, log message)
- [ ] CLI reconnects after daemon restart (Messages channel closed properly)
- [ ] `--socket /custom/path.sock` is preserved through Derive()
- [ ] MCPBinDir default matches actual bridge installation path
- [ ] `cograw --backend mock` starts without a GGUF model file
- [ ] All unit tests pass in affected repos

**Risk:** Low. Each fix is isolated and well-understood.

**Estimated effort:** 2-3 hours total.

## Implementation Order

```
Phase 1 (ISO Boot)     ──── immediate, unblocks real hardware
Phase 2 (Docker Boot)  ──── after Phase 1, unblocks container deployment
Phase 3 (TOML Config)  ──── independent, can run in parallel with Phase 1/2
Phase 4 (Reliability)  ──── independent, can run in parallel with Phase 1/2/3
```

Phases 1 and 2 are sequential (Phase 2 benefits from Phase 1's init script knowledge). Phases 3 and 4 are fully independent and can be done in parallel with anything.

## Cross-Repo Impact

| Phase | Repos Affected | Changes |
|-------|---------------|---------|
| Phase 1 | `cognitiveos-alpine-distro` | inittab, 3 new init scripts, genapkovl update |
| Phase 2 | `cognitiveos-alpine-distro` | 7 Dockerfiles, entrypoint script, 6 package lists |
| Phase 3 | `cognitiveosd`, `cognitiveos-alpine-distro` | go.mod, config.go, main.go, config.toml |
| Phase 4 | `inference`, `cli`, `cognitiveosd` | coginfer main.go, client.go, config.go, cograw main.go |

**Build chain dependency:** All phases depend on the existing build pipeline (`build-binaries.sh` → `build-overlay.sh` → ISO/Docker packaging). No changes to the build pipeline are needed — the gap is purely in runtime init, not build/install.

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

## Risk Register

| Risk | Phase | Likelihood | Impact | Mitigation |
|------|-------|-----------|--------|------------|
| OpenRC dependency ordering wrong | 1 | Medium | High | Test in QEMU before hardware; use `rc-order` to verify |
| tini not in Alpine community repo | 2 | Low | Medium | Verify `apk add tini` works; fallback to `--init` flag |
| TOML library conflicts with Go version | 3 | Low | Low | BurntSushi/toml has zero deps; test with `go mod tidy` |
| cograw model missing in Docker | 2 | Medium | Medium | Entrypoint continues even if cograw fails; log warning |
| Derive() fix breaks other derived paths | 4 | Low | Medium | Only skip SocketPath override; all other derivations unchanged |
