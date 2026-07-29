# Boot Flow Verification Plan

Version: 1.0.0-draft

## Overview

This document defines the verification strategy for the CognitiveOS boot flow. With `coginit` as the unified PID 1, the boot sequence is standardized across ISO and Docker. This plan provides step-by-step verification procedures for both environments and error scenarios.

See also: `specs/boot-flow.md` in product-specs for the full boot flow specification. See `plan/boot-startup-analysis.md` for the implementation plan.

## Verification Environment

### ISO Testing

- **Tool:** QEMU (x86_64 and aarch64)
- **Image:** Built ISO from `cognitiveos-alpine-distro`
- **Expected boot time:** ~3-5 seconds to "CognitiveOS ready"

### Docker Testing

- **Tool:** Docker Engine
- **Image:** Built from `docker/release/standard-x86_64/Dockerfile` with coginit as ENTRYPOINT
- **Expected start time:** ~3-5 seconds to "CognitiveOS ready"

### Hardware Testing

- **Device:** Raspberry Pi 4 (armv7) or Raspberry Pi 400 (aarch64)
- **Image:** Built ISO from `cognitiveos-alpine-distro`
- **Expected boot time:** ~5-10 seconds to "CognitiveOS ready"

---

## Phase 1 Verification: ISO Boot Chain

### Test 1.1: coginit starts and boots system

**Precondition:** ISO built with coginit as init

**Steps:**
1. Build ISO: `make release-variant CLASS=standard ARCH=x86_64`
2. Boot in QEMU: `qemu-system-x86_64 -cdrom build/release/cognitiveos-*-standard-x86_64.iso -m 2048 -nographic`
3. Watch boot output on serial console

**Expected output:**
```
[coginit] Detected bare-metal environment
[coginit] Starting in bare-metal mode
[coginit] Mounted /proc
[coginit] Mounted /sys
[coginit] Mounted /tmp
[coginit] Mounted /run
[coginit] Mounted /dev/pts
[coginit] Loopback network configured
[coginit] Runtime directories ready
[coginit] Installing boot-stage dependencies...
[coginit] Starting cograw...
[coginit] cograw started (PID ...)
[coginit] cograw raw.sock ready
[coginit] Starting coginfer...
[coginit] coginfer started (PID ...)
[coginit] coginfer HTTP :11434 healthy
[coginit] Starting cognitiveosd...
[coginit] cognitiveosd started (PID ...)
[coginit] cognitiveosd daemon.sock ready
[coginit] Runtime-stage dependencies installed
[coginit] All engines started. Starting backdoor monitor...
[coginit] Starting cognitiveos-cli...
CognitiveOS ready
```

**Pass criteria:** All stages execute in order: virtual filesystems → loopback → boot deps → cograw → coginfer → cognitiveosd → runtime deps → CLI. No `[coginit] Warning:` failures for core engines.

### Test 1.2: Service startup ordering

**Precondition:** ISO booted to "CognitiveOS ready"

**Steps:**
1. After boot completes, log in on tty2 (getty)
2. Run: `ps aux | grep -E 'cograw|coginfer|cognitiveosd|coginit'`

**Expected process tree (bare-metal):**
```
coginit (PID 1)
  ├── cograw           (listening on raw.sock)
  ├── coginfer         (listening on HTTP :11434)
  ├── cognitiveosd     (listening on daemon.sock)
  └── cognitiveos-cli  (on tty1)
```

**Pass criteria:** coginit is PID 1. All 4 child processes present. No zombie processes.

### Test 1.3: Sockets exist and are accessible

**Precondition:** Boot completed, "CognitiveOS ready" displayed

**Steps:**
1. Log in on tty2
2. Run: `ls -la /cognitiveos/run/`
3. Run: `ss -xl | grep -E 'raw|daemon'`
4. Run: `curl -s http://127.0.0.1:11434/health`

**Expected output:**
```
srw------- 1 root root 0 raw.sock
srw------- 1 root root 0 daemon.sock

State   Recv-Q  Send-Q  Local Address   Peer Address   ...
0   0   /cognitiveos/run/raw.sock
0   0   /cognitiveos/run/daemon.sock

{"status":"ok"}
```

**Pass criteria:** Both sockets exist with 0600 permissions. HTTP health endpoint responds with `{"status":"ok"}`.

### Test 1.4: Process tree matches spec

**Precondition:** Boot completed

**Steps:**
1. Log in on tty2
2. Run: `ps aux`
3. Run: `pstree`

**Expected processes (bare-metal):**
```
coginit (PID 1)
  ├── cograw
  ├── coginfer
  ├── cognitiveosd───{network-mcp}{audio-mcp}{display-mcp}{gpio-mcp}{serial-mcp}
  ├── cognitiveos-cli (tty1)
  ├── getty (tty2)
  ├── acpid
  └── syslogd
```

**Pass criteria:** coginit is PID 1. All 4 CognitiveOS processes present (cograw, coginfer, cognitiveosd, cognitiveos-cli). cognitiveosd has MCP bridge child processes. No zombie processes.

### Test 1.5: cpm-boot-deps and cpm-runtime-deps executed

**Precondition:** Boot completed

**Steps:**
1. Log in on tty2
2. Check coginit log: `cat /cognitiveos/logs/coginit.log | grep -E 'boot-stage|runtime-stage'`

**Expected output:**
```
[coginit] Installing boot-stage dependencies...
[coginit] boot-stage dependencies installed
[coginit] Installing runtime-stage dependencies...
[coginit] runtime-stage dependencies installed
```

**Pass criteria:** Both stages ran and completed. No warning messages from cpm.

### Test 1.6: coginit process supervision (auto-restart)

**Precondition:** Boot completed

**Steps:**
1. Log in on tty2
2. Kill cograw: `kill $(pgrep cograw)`
3. Wait 2 seconds
4. Run: `ps aux | grep cograw`
5. Check coginit log: `cat /cognitiveos/logs/coginit.log | grep "cograw exited"`

**Expected:** cograw reappears in process list within 2 seconds. Log shows: `[coginit] cograw exited: ... restarting in 500ms`.

**Pass criteria:** coginit supervision restarts cograw automatically. raw.sock reappears.

### Test 1.7: Clean shutdown

**Precondition:** Boot completed

**Steps:**
1. Log in on tty2
2. Run: `poweroff` (or send SIGTERM to PID 1)
3. Watch serial console output

**Expected output:**
```
[coginit] SIGTERM received, forwarding to all children
[coginit] Terminating cognitiveosd (PID ...)...
[coginit] Terminating coginfer (PID ...)...
[coginit] Terminating cograw (PID ...)...
[cograw] shutting down
[coginfer] shutting down coginfer...
[coginfer] coginfer stopped
[cognitiveosd] Received signal, shutting down
[coginit] All engines terminated
[coginit] Powering off...
```

**Pass criteria:** All processes terminated gracefully. Logs show clean shutdown ordered by coginit. System powers off.

---

## Phase 2 Verification: Docker Boot Chain

### Test 2.1: Docker build succeeds

**Precondition:** Docker images use coginit as ENTRYPOINT

**Steps:**
1. Build: `make docker-release CLASS=standard ARCH=x86_64 VERSION=test`
2. Check image: `docker images | grep cognitiveos`

**Pass criteria:** Image builds without errors. Image size is reasonable (within 10% of current).

### Test 2.2: Container starts with all daemons

**Precondition:** Docker image built

**Steps:**
1. Run: `docker run -d --name test-cognitiveos cognitiveos:standard-x86_64-test`
2. Wait 5 seconds
3. Exec into container: `docker exec test-cognitiveos ps aux`
4. Check process list

**Expected processes (Docker mode):**
```
coginit (PID 1, then execs into cognitiveos-cli)
cognitiveos-cli (replaces coginit as PID 1)
cograw
coginfer
cognitiveosd
```

Note: In Docker mode, coginit starts all engines then `syscall.Exec` replaces itself with the CLI. The CLI becomes PID 1 after exec. Background processes (cograw, coginfer, cognitiveosd) are adopted by PID 1.

**Pass criteria:** All 4 processes present (CLI replaces coginit). coginfer, cograw, cognitiveosd running in background.

### Test 2.3: Sockets exist in container

**Precondition:** Container running

**Steps:**
1. Run: `docker exec test-cognitiveos ls -la /cognitiveos/run/`
2. Run: `docker exec test-cognitiveos ss -xl`
3. Run: `docker exec test-cognitiveos curl -s http://127.0.0.1:11434/health`

**Pass criteria:** raw.sock and daemon.sock exist. HTTP health responds.

### Test 2.4: coginit is ENTRYPOINT

**Precondition:** Container running

**Steps:**
1. Check Dockerfile: `grep ENTRYPOINT docker/release/standard-x86_64/Dockerfile`

**Expected output:** `ENTRYPOINT ["/usr/local/bin/coginit"]`

**Pass criteria:** coginit is ENTRYPOINT, not tini or shell. No tini dependency.

### Test 2.5: Docker degraded mode (missing model)

**Precondition:** No model file volume-mounted.

**Steps:**
1. Run: `docker run -d --name test-degraded cognitiveos:standard-x86_64-test` (no `-v` for model)
2. Wait 5 seconds
3. Exec: `docker exec test-degraded ps aux` — verify cograw running
4. Exec: `docker exec test-degraded cat /cognitiveos/logs/cograw.log` — verify mock mode log message
5. Exec: `docker exec test-degraded curl -s http://127.0.0.1:11434/health` — verify coginfer responds
6. Exec: `docker exec test-degraded ls -la /cognitiveos/run/` — verify both sockets exist

**Expected:** cograw starts (backend determined by coginit's start args). coginfer starts normally. cognitiveosd connects to both. CLI renders TUI. System operates in degraded mode if guardrail is in mock mode.

**Pass criteria:** All processes running. Both sockets present. CLI responsive. No crash loops.

### Test 2.6: Docker production mode (model mounted)

**Precondition:** Phase 2 + Phase 4.1 fixes applied. Model file volume-mounted.

**Steps:**
1. Run: `docker run -d --name test-prod -v /path/to/raw-model.gguf:/cognitiveos/models/raw/raw-model.gguf:ro cognitiveos:standard-x86_64-test`
2. Wait 5 seconds
3. Exec: `docker exec test-prod ps aux` — verify cograw running with `--backend cgo`
4. Exec: `docker exec test-prod cat /cognitiveos/logs/cograw.log` — verify GGUF loaded

**Expected:** cograw starts in cgo mode, loads GGUF, opens raw.sock. Full functionality.

**Pass criteria:** All processes running in production mode. Model loaded. Full inference available.

### Test 2.7: Clean container shutdown

**Precondition:** Container running

**Steps:**
1. Run: `docker stop test-cognitiveos -t 10`
2. Run: `docker inspect test-cognitiveos --format='{{.State.Status}}'`
3. Run: `docker logs test-cognitiveos` — check for graceful shutdown messages

**Expected output in logs:**
```
[coginit] SIGTERM received, forwarding to all children
[coginit] Terminating cognitiveosd (PID ...)...
[coginit] Terminating coginfer (PID ...)...
[coginit] Terminating cograw (PID ...)...
```

**Pass criteria:** Container status is `exited`. No ` killed` status (indicates SIGKILL, meaning 10s timeout wasn't enough). Logs show clean shutdown messages from coginit.

### Test 2.8: Container restart

**Precondition:** Container stopped

**Steps:**
1. Run: `docker start test-cognitiveos`
2. Wait 5 seconds
3. Exec: `docker exec test-cognitiveos ps aux`

**Pass criteria:** All processes restart. Sockets recreated. CLI reconnects.

---

## Phase 3 Verification: TOML Config

### Test 3.1: Default config loaded

**Precondition:** System built with config.toml support

**Steps:**
1. Boot ISO (or run Docker)
2. Check daemon log: `cat /cognitiveos/logs/cognitiveosd.log`
3. Verify model path from coginit: check `cat /cognitiveos/logs/cograw.log` for model path

**Pass criteria:** Daemon shows config values applied. cograw starts with model path from default/config.toml/env.

### Test 3.2: coginit reads config.toml model path

**Precondition:** System built with config.toml at `/etc/cognitiveos/config.toml`

**Steps:**
1. Set `raw_model.model = "/custom/path/model.gguf"` in config.toml
2. Rebuild and boot
3. Check which model path cograw uses: `cat /cognitiveos/logs/cograw.log | grep "raw model"`

**Pass criteria:** cograw loads model from the config.toml path (unless overridden by env var or `--model` flag).

### Test 3.3: Custom TOML values applied

**Precondition:** System built with config.toml support

**Steps:**
1. Modify overlay config.toml: change `audit_interval_seconds = 120`
2. Rebuild and boot
3. Verify daemon uses 120s interval (check audit timestamps in log)

**Pass criteria:** Audit timestamps appear 120 seconds apart, not 60.

### Test 3.4: Env vars override TOML

**Precondition:** System built with config.toml support

**Steps:**
1. Set `COGNITIVEOS_AUDIT_INTERVAL=30` and `COGNITIVEOS_RAW_MODEL_PATH=/env/path/model.gguf` in environment
2. Boot with custom config (audit_interval_seconds = 120, raw_model.model = "/toml/path/model.gguf")
3. Check audit timestamps: should be 30s apart
4. Check cograw model path: should be `/env/path/model.gguf`

**Pass criteria:** Env vars override TOML values. Audit interval and model path match env values.

### Test 3.5: CLI flags override env and TOML

**Precondition:** System built with config.toml support

**Steps:**
1. Start system with `COGNITIVEOS_RAW_MODEL_PATH=/env/path/model.gguf`
2. Config.toml has `raw_model.model = "/toml/path/model.gguf"`
3. Pass `--model /flag/path/model.gguf` to coginit
4. Check cograw model path: should be `/flag/path/model.gguf`

**Pass criteria:** `--model` flag wins over all other sources.

---

## Phase 4 Verification: Reliability Fixes

### Test 4.1: coginfer graceful shutdown

**Precondition:** System booted

**Steps:**
1. Boot system (ISO or Docker)
2. Send SIGTERM to coginfer: `kill -TERM $(pgrep coginfer)`
3. Check coginfer log for shutdown message: `cat /cognitiveos/logs/coginfer.log`
4. Verify HTTP port closed: `curl http://127.0.0.1:11434/health` should fail

**Expected log:**
```
shutting down coginfer...
coginfer stopped
```

**Pass criteria:** coginfer logs graceful shutdown with 30s timeout. HTTP port closed. Process exits.

### Test 4.2: CLI reconnection after daemon restart

**Precondition:** System booted

**Steps:**
1. Boot system, verify TUI is running
2. Kill cognitiveosd: `kill $(pgrep cognitiveosd)`
3. Wait 3 seconds (coginit supervision restarts cognitiveosd)
4. Verify TUI reconnects and becomes responsive again

**Pass criteria:** coginit supervision restarts cognitiveosd. TUI shows brief "Connecting..." state, then resumes normal operation. No user intervention required.

### Test 4.3: config.Derive() preserves --socket flag

**Precondition:** cognitiveosd built

**Steps:**
1. Start daemon with `--socket /tmp/custom.sock`
2. Verify socket created at `/tmp/custom.sock`
3. Verify socket NOT created at `/cognitiveos/run/daemon.sock`

**Pass criteria:** Custom socket path is used. Default path is not created.

### Test 4.4: MCPBinDir default corrected

**Precondition:** cognitiveosd built

**Steps:**
1. Start daemon without MCPBinDir env var or flag
2. Check daemon config: `MCPBinDir` should be `/usr/local/lib/cognitiveos/bridges`
3. Verify bridges directory exists

**Pass criteria:** MCPBinDir defaults to correct path. Bridges directory present.

### Test 4.5: cograw --backend flag

**Precondition:** cograw built

**Steps:**
1. Run with mock backend: `cograw --backend mock --socket /tmp/test-raw.sock`
2. Verify raw.sock created
3. Send SIGTERM, verify clean shutdown
4. Run with cgo backend: `cograw --backend cgo --model /path/to/model.gguf --socket /tmp/test-raw2.sock`
5. Verify model loaded

**Pass criteria:** `--backend mock` starts without GGUF. `--backend cgo` loads model normally.

---

## Integration Test: Full Boot to Steady State

### Test INT-1: ISO end-to-end

**Steps:**
1. Build ISO: `make release-variant CLASS=standard ARCH=x86_64`
2. Boot in QEMU with 2GB RAM
3. Wait for "CognitiveOS ready" on tty1
4. Total time from power-on to ready should be under 10 seconds
5. Verify all sockets exist
6. Verify all processes running
7. Type a prompt in TUI, verify response
8. Reboot, verify clean shutdown

**Pass criteria:** All individual tests pass. No errors in logs. System reaches steady state.

### Test INT-2: Docker end-to-end

**Steps:**
1. Build: `docker build -t cognitiveos:test -f docker/release/standard-x86_64/Dockerfile .`
2. Run: `docker run -d --name test cognitiveos:test`
3. Wait 5 seconds
4. Exec: verify all processes, sockets, health
5. Stop: `docker stop test -t 10`
6. Verify clean exit

**Pass criteria:** All individual tests pass. Container starts and stops cleanly.

### Test INT-3: Error recovery

**Steps:**
1. Boot ISO in QEMU
2. Delete raw model: `rm /cognitiveos/models/raw/raw-model.gguf`
3. Reboot
4. Verify system enters error state (cograw fails, cognitiveosd fails, CLI shows error)
5. Restore model file
6. Reboot
7. Verify system recovers and reaches "CognitiveOS ready"

**Pass criteria:** System degrades gracefully when model is missing. System recovers when model is restored.

---

## Test Matrix

| Test | Phase | Environment | Priority | Automated |
|------|-------|-------------|----------|-----------|
| 1.1 coginit boot output | coginit | QEMU ISO | Critical | No (manual observation) |
| 1.2 Service ordering | coginit | QEMU ISO | Critical | Yes (`ps` check) |
| 1.3 Socket existence | coginit | QEMU ISO | Critical | Yes (curl check) |
| 1.4 Process tree | coginit | QEMU ISO | High | Yes (`ps` check) |
| 1.5 cpm deps executed | coginit | QEMU ISO | Medium | Yes (log check) |
| 1.6 coginit supervision | coginit | QEMU ISO | High | Yes (kill + wait) |
| 1.7 Clean shutdown | coginit | QEMU ISO | High | No (manual observation) |
| 2.1 Docker build | coginit | Docker | Critical | Yes (exit code) |
| 2.2 Container processes | coginit | Docker | Critical | Yes (`ps` check) |
| 2.3 Container sockets | coginit | Docker | Critical | Yes (curl check) |
| 2.4 coginit ENTRYPOINT | coginit | Docker | High | Yes (Dockerfile check) |
| 2.5 Docker degraded mode | coginit | Docker | Critical | Yes (ps + log check) |
| 2.6 Docker production mode | coginit | Docker | High | Yes (ps + log check) |
| 2.7 Clean shutdown | coginit | Docker | High | Yes (exit code) |
| 2.8 Container restart | coginit | Docker | Medium | Yes (ps check) |
| 3.1 Default config | config | ISO or Docker | High | Yes (log check) |
| 3.2 coginit config.toml | config | ISO or Docker | High | Yes (log check) |
| 3.3 Custom TOML | config | ISO or Docker | Medium | Yes (timestamp check) |
| 3.4 Env override | config | ISO or Docker | Medium | Yes (timestamp check) |
| 3.5 Flag override | config | ISO or Docker | Low | Yes (flag check) |
| 4.1 coginfer SIGTERM | reliability | ISO or Docker | High | Yes (curl check) |
| 4.2 CLI reconnect | reliability | ISO or Docker | High | Yes (manual kill) |
| 4.3 Derive socket | reliability | ISO or Docker | Medium | Yes (socket check) |
| 4.4 MCPBinDir | reliability | ISO or Docker | Medium | Yes (ls check) |
| 4.5 cograw mock | reliability | Local build | Low | Yes (health check) |
| INT-1 ISO e2e | All | QEMU ISO | Critical | No (manual) |
| INT-2 Docker e2e | All | Docker | Critical | No (manual) |
| INT-3 Error recovery | All | QEMU ISO | Medium | No (manual) |

## Automation Notes

- Tests marked "Yes" can be scripted as shell scripts that return exit 0 on pass, exit 1 on fail
- Tests marked "No" require manual observation (boot output, TUI rendering)
- A CI workflow can run the automated tests against QEMU and Docker after each phase merge
- Hardware tests (Raspberry Pi) should be run manually before each release
