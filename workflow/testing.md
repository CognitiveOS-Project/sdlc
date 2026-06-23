# Testing Strategy

## Layers of Testing

### 1. Unit Tests (per repo)

**Location:** `*_test.go` alongside source files (Go convention)

**Scope:** Individual functions, methods, and packages

**Requirements:**
- All exported functions have unit tests
- Table-driven tests for edge cases
- No external dependencies (filesystem, network, hardware mocked)

**Run:** `go test ./...`

### 2. Integration Tests (per repo)

**Location:** `tests/` directory at repo root

**Scope:** Component-level interactions within a single repo

**Examples:**
- cpm: install a .cgp → verify files exist → remove → verify cleaned
- cognitiveosd: connect to socket → send message → verify response
- cli: receive output_deliver → verify display state transition

**Run:** `go test ./tests/...` (may require root for socket tests)

### 3. Cross-Component Tests (across repos)

**Location:** `cognitiveos-distro/tests/` or standalone test suite

**Scope:** Interactions between 2+ CognitiveOS components

**Examples:**
- cli + cognitiveosd: start daemon, start CLI, send text, verify response
- cognitiveosd + display-mcp: register bridge → invoke tool → verify result
- cpm + cognitiveosd: install patch → verify MCP server spawned

**Run:** Requires built binaries. `make test-integration`

### 4. Hardware Tests (real devices)

**Location:** `cognitiveos-distro/tests/hardware/`

**Scope:** Tests requiring physical hardware (framebuffer, audio, GPIO)

**Examples:**
- display-mcp: render image → capture framebuffer → verify pixel output
- audio-mcp: play audio → verify ALSA device activity
- gpio-mcp: write pin → read back → verify value

**Run:** Must be on real hardware. `make test-hardware`

### 5. Boot Tests (full system)

**Location:** `cognitiveos-distro/tests/boot/`

**Scope:** Full OS boot in QEMU or on hardware

**Examples:**
- ISO boots to CLI prompt
- Raw Model loads automatically
- "CognitiveOS ready" displayed within 10 seconds of power-on

**Run:** `make test-boot` (requires QEMU + ISO)

## CI Pipeline

```
Push to PR branch
  → Lint (gofmt, shellcheck)
  → Unit tests (go test ./...)
  → Build (go build ./cmd/...)
  → Integration tests (go test ./tests/...)
  → [optional] Cross-compile for arm64
```

See [ci-cd.md](ci-cd.md) for full pipeline definitions.

## Test Fixtures

- Sample .cgp archives: `cpm/tests/fixtures/*.cgp`
- Test images: `core-mcp-bridges/tests/fixtures/test.jpg`
- Test audio: `core-mcp-bridges/tests/fixtures/test.wav`
- Mock MCP servers: `cognitiveosd/tests/mocks/`

## Device Matrix

| Device | Tests to run | Frequency |
|--------|-------------|-----------|
| QEMU (x86_64) | Unit + Integration + Boot | Every PR |
| QEMU (aarch64) | Boot + Cross-compile | Weekly |
| Raspberry Pi 4 | All | Per release |
| Raspberry Pi Zero 2 | Hardware + Boot | Per release |
| x86_64 laptop | Hardware (real display, audio, Wi-Fi) | Per release |
