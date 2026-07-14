# Boot Flow Verification Plan

Version: 1.0.0-draft

## Overview

This document defines the verification strategy for the CognitiveOS boot flow after all four implementation phases are complete. It provides step-by-step verification procedures for ISO, Docker, and error scenarios. Each procedure maps to specific deliverables from the implementation plan.

See also: `specs/boot-flow.md` in product-specs for the full boot flow specification.

## Verification Environment

### ISO Testing

- **Tool:** QEMU (x86_64 and aarch64)
- **Image:** Built ISO from `cognitiveos-alpine-distro` after Phase 1 fixes
- **Expected boot time:** ~3-5 seconds to "CognitiveOS ready"

### Docker Testing

- **Tool:** Docker Engine
- **Image:** Built from `docker/release/standard-x86_64/Dockerfile` after Phase 2 fixes
- **Expected start time:** ~3-5 seconds to "CognitiveOS ready"

### Hardware Testing

- **Device:** Raspberry Pi 4 (armv7) or Raspberry Pi 400 (aarch64)
- **Image:** Built ISO from `cognitiveos-alpine-distro` after Phase 1 fixes
- **Expected boot time:** ~5-10 seconds to "CognitiveOS ready"

---

## Phase 1 Verification: ISO Boot Chain

### Test 1.1: Inittab contains OpenRC stages

**Precondition:** Phase 1 fixes applied to `overlay/etc/inittab`

**Steps:**
1. Build ISO: `make release-variant CLASS=standard ARCH=x86_64`
2. Boot in QEMU: `qemu-system-x86_64 -cdrom build/release/cognitiveos-*-standard-x86_64.iso -m 2048 -nographic`
3. Watch boot output on serial console

**Expected output:**
```
* Starting system logger ...                          [ ok ]
* Starting device manager ...                         [ ok ]
* Starting hardware drivers ...                       [ ok ]
* Loading kernel modules ...                          [ ok ]
* Syncing hardware clock ...                          [ ok ]
* Starting CognitiveOS Raw Model Guardrail ...        [ ok ]
* Starting CognitiveOS Wide Model Inference ...       [ ok ]
* Installing boot-stage dependencies ...              [ ok ]
* Starting acpid ...                                  [ ok ]
* Starting CognitiveOS Daemon ...                     [ ok ]
* Processing runtime dependency queue ...             [ ok ]
CognitiveOS ready
```

**Pass criteria:** All `openrc sysinit`, `openrc boot`, and `openrc default` stages execute. No `[ !! ]` failures for CognitiveOS services.

### Test 1.2: Service dependency ordering

**Precondition:** Phase 1 fixes applied

**Steps:**
1. Boot ISO in QEMU
2. After boot completes, SSH or use tty2 getty to log in
3. Run: `rc-status -a`
4. Run: `rc-order -l default`

**Expected output of `rc-order -l default`:**
```
cograw coginfer cpm-boot-deps acpid cognitiveosd cpm-runtime-deps
```

**Pass criteria:** cograw appears before cognitiveosd. coginfer appears before cognitiveosd. cpm-boot-deps appears before cognitiveosd. cpm-runtime-deps appears after cognitiveosd.

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

**Expected processes:**
```
init─┬─cograw
     ├─coginfer
     ├─cognitiveosd───{network-mcp}{audio-mcp}{display-mcp}{gpio-mcp}{serial-mcp}
     ├─cognitiveos-cli (tty1)
     ├─cognitiveos-cli (ttyS0)
     ├─getty (tty2)
     ├─acpid
     └─syslogd
```

**Pass criteria:** All 8 processes present. cognitiveosd has MCP bridge child processes. No zombie processes.

### Test 1.5: cpm-boot-deps and cpm-runtime-deps executed

**Precondition:** Boot completed

**Steps:**
1. Log in on tty2
2. Run: `ls /var/lib/cpm/queue/`
3. Check if boot-stage entries are marked installed
4. Run: `rc-status default | grep -E 'boot-deps|runtime-deps'`

**Expected output:** boot-deps and runtime-deps should show `started` or `exited` status (one-shot services).

**Pass criteria:** Both services ran and exited cleanly. Queue entries marked as installed.

### Test 1.6: OpenRC service respawning

**Precondition:** Boot completed

**Steps:**
1. Log in on tty2
2. Kill cograw: `kill $(cat /run/cograw.pid)`
3. Wait 5 seconds
4. Run: `ps aux | grep cograw`
5. Check if OpenRC respawned it

**Expected:** cograw reappears in process list within 5 seconds. OpenRC logs `cograw superseded`.

**Pass criteria:** Service respawns automatically. raw.sock reappears.

### Test 1.7: Clean shutdown

**Precondition:** Boot completed

**Steps:**
1. Log in on tty2
2. Run: `reboot`
3. Watch serial console output

**Expected output:**
```
* Saving package cache ...                            [ ok ]
* Killing all processes ...                           [ ok ]
* Remounting filesystems read-only ...                [ ok ]
```

**Pass criteria:** All shutdown services execute. No hung processes. System powers off cleanly.

---

## Phase 2 Verification: Docker Boot Chain

### Test 2.1: Docker build succeeds

**Precondition:** Phase 2 fixes applied to Dockerfiles and package lists

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

**Expected processes:**
```
tini
cognitiveos-cli
cograw
coginfer
cognitiveosd
```

**Pass criteria:** All 5 processes present. tini is PID 1.

### Test 2.3: Sockets exist in container

**Precondition:** Container running

**Steps:**
1. Run: `docker exec test-cognitiveos ls -la /cognitiveos/run/`
2. Run: `docker exec test-cognitiveos ss -xl`
3. Run: `docker exec test-cognitiveos curl -s http://127.0.0.1:11434/health`

**Pass criteria:** raw.sock and daemon.sock exist. HTTP health responds.

### Test 2.4: Tini is PID 1

**Precondition:** Container running

**Steps:**
1. Run: `docker exec test-cognitiveos cat /proc/1/cmdline | tr '\0' ' '`

**Expected output:** `/sbin/tini --`

**Pass criteria:** tini is PID 1, not cognitiveos-cli or busybox init.

### Test 2.5: Docker degraded mode (missing model)

**Precondition:** Phase 2 + Phase 4.1 fixes applied. No model file volume-mounted.

**Steps:**
1. Run: `docker run -d --name test-degraded cognitiveos:standard-x86_64-test` (no `-v` for model)
2. Wait 5 seconds
3. Exec: `docker exec test-degraded ps aux` — verify cograw running with `--backend mock`
4. Exec: `docker exec test-degraded cat /cognitiveos/logs/cograw.log` — verify mock mode log message
5. Exec: `docker exec test-degraded curl -s http://127.0.0.1:11434/health` — verify coginfer responds
6. Exec: `docker exec test-degraded ls -la /cognitiveos/run/` — verify both sockets exist

**Expected:** cograw starts in mock mode, logs warning about missing model. coginfer starts normally. cognitiveosd connects to both. CLI renders TUI. System operates in degraded mode (guardrail active, no inference).

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

**Pass criteria:** Container status is `exited`. No ` killed` status (would indicate SIGKILL). Check logs: `docker logs test-cognitiveos` for clean shutdown messages.

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

**Precondition:** Phase 3 fixes applied, daemon built

**Steps:**
1. Boot ISO (or run Docker)
2. Check daemon log: `cat /cognitiveos/logs/cognitiveosd.log`
3. Verify config values applied

**Pass criteria:** Log shows "Loaded config from /etc/cognitiveos/config.toml". Default values match expected defaults.

### Test 3.2: Custom TOML values applied

**Precondition:** Phase 3 fixes applied

**Steps:**
1. Modify overlay config.toml: change `audit_interval_seconds = 120`
2. Rebuild and boot
3. Verify daemon uses 120s interval (check audit timestamps in log)

**Pass criteria:** Audit timestamps appear 120 seconds apart, not 60.

### Test 3.3: Env vars override TOML

**Precondition:** Phase 3 fixes applied

**Steps:**
1. Set `COGNITIVEOS_AUDIT_INTERVAL=30` in environment
2. Boot with custom config (audit_interval_seconds = 120)
3. Check audit timestamps

**Pass criteria:** Audit timestamps appear 30 seconds apart (env overrides TOML).

### Test 3.4: CLI flags override env and TOML

**Precondition:** Phase 3 fixes applied

**Steps:**
1. Start daemon with `--audit-interval 10`
2. Set `COGNITIVEOS_AUDIT_INTERVAL=30`
3. Set TOML `audit_interval_seconds = 120`
4. Check audit timestamps

**Pass criteria:** Audit timestamps appear 10 seconds apart (flag wins).

---

## Phase 4 Verification: Reliability Fixes

### Test 4.1: coginfer graceful shutdown

**Precondition:** Phase 4 fixes applied

**Steps:**
1. Boot system (ISO or Docker)
2. Send SIGTERM to coginfer: `kill -TERM $(cat /run/coginfer.pid)`
3. Check coginfer log for shutdown message
4. Verify HTTP port closed: `curl http://127.0.0.1:11434/health` should fail

**Pass criteria:** coginfer logs "Received SIGTERM, shutting down gracefully". Model unloaded. HTTP port closed. Process exits with code 0.

### Test 4.2: CLI reconnection after daemon restart

**Precondition:** Phase 4 fixes applied

**Steps:**
1. Boot system, verify TUI is running
2. Kill cognitiveosd: `kill $(cat /run/cognitiveosd.pid)`
3. Wait 3 seconds (OpenRC respawns cognitiveosd)
4. Verify TUI reconnects and becomes responsive again

**Pass criteria:** TUI shows brief "Reconnecting..." state, then resumes normal operation. No user intervention required.

### Test 4.3: config.Derive() preserves --socket flag

**Precondition:** Phase 4 fixes applied

**Steps:**
1. Start daemon with `--socket /tmp/custom.sock`
2. Verify socket created at `/tmp/custom.sock`
3. Verify socket NOT created at `/cognitiveos/run/daemon.sock`

**Pass criteria:** Custom socket path is used. Default path is not created.

### Test 4.4: MCPBinDir default corrected

**Precondition:** Phase 4 fixes applied

**Steps:**
1. Boot system without MCPBinDir env var or flag
2. Check daemon config: `MCPBinDir` should be `/usr/local/lib/cognitiveos/bridges`
3. Verify bridges exist at that path: `ls /usr/local/lib/cognitiveos/bridges/`

**Pass criteria:** MCPBinDir defaults to correct path. Bridges are found and loaded.

### Test 4.5: cograw --backend flag

**Precondition:** Phase 4.1 fixes applied

**Steps:**
1. Build cograw: `go build -o cograw ./cmd/cograw`
2. Run with mock backend (no model file needed): `./cograw --backend mock --socket /tmp/test-raw.sock`
3. Verify raw.sock created: `ls -la /tmp/test-raw.sock`
4. Verify healthcheck responds
5. Send SIGTERM, verify clean shutdown
6. Run with cgo backend and model: `./cograw --backend cgo --model /path/to/model.gguf --socket /tmp/test-raw2.sock`
7. Verify raw.sock created and model loaded

**Pass criteria:** `--backend mock` starts without GGUF. `--backend cgo` loads model normally. Both shut down cleanly on SIGTERM.

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
| 1.1 Inittab stages | 1 | QEMU ISO | Critical | No (manual observation) |
| 1.2 Service ordering | 1 | QEMU ISO | Critical | Yes (`rc-order` check) |
| 1.3 Socket existence | 1 | QEMU ISO | Critical | Yes (curl check) |
| 1.4 Process tree | 1 | QEMU ISO | High | Yes (`ps` check) |
| 1.5 cpm deps executed | 1 | QEMU ISO | Medium | Yes (queue check) |
| 1.6 Service respawn | 1 | QEMU ISO | High | Yes (kill + wait) |
| 1.7 Clean shutdown | 1 | QEMU ISO | High | No (manual observation) |
| 2.1 Docker build | 2 | Docker | Critical | Yes (exit code) |
| 2.2 Container processes | 2 | Docker | Critical | Yes (`ps` check) |
| 2.3 Container sockets | 2 | Docker | Critical | Yes (curl check) |
| 2.4 Tini PID 1 | 2 | Docker | High | Yes (`/proc/1/cmdline`) |
| 2.5 Docker degraded mode | 2 | Docker | Critical | Yes (ps + log check) |
| 2.6 Docker production mode | 2 | Docker | High | Yes (ps + log check) |
| 2.7 Clean shutdown | 2 | Docker | High | Yes (exit code) |
| 2.8 Container restart | 2 | Docker | Medium | Yes (ps check) |
| 3.1 Default config | 3 | ISO or Docker | High | Yes (log check) |
| 3.2 Custom TOML | 3 | ISO or Docker | Medium | Yes (timestamp check) |
| 3.3 Env override | 3 | ISO or Docker | Medium | Yes (timestamp check) |
| 3.4 Flag override | 3 | ISO or Docker | Low | Yes (timestamp check) |
| 4.1 coginfer SIGTERM | 4 | ISO or Docker | High | Yes (curl check) |
| 4.2 CLI reconnect | 4 | ISO or Docker | High | Yes (manual kill) |
| 4.3 Derive socket | 4 | ISO or Docker | Medium | Yes (socket check) |
| 4.4 MCPBinDir | 4 | ISO or Docker | Medium | Yes (ls check) |
| 4.5 cograw mock | 4 | Local build | Low | Yes (health check) |
| INT-1 ISO e2e | All | QEMU ISO | Critical | No (manual) |
| INT-2 Docker e2e | All | Docker | Critical | No (manual) |
| INT-3 Error recovery | All | QEMU ISO | Medium | No (manual) |

## Automation Notes

- Tests marked "Yes" can be scripted as shell scripts that return exit 0 on pass, exit 1 on fail
- Tests marked "No" require manual observation (boot output, TUI rendering)
- A CI workflow can run the automated tests against QEMU and Docker after each phase merge
- Hardware tests (Raspberry Pi) should be run manually before each release
