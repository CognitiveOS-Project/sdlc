# Mission Script: Implement cogsdk Universal SDK

## Mission Name
Implement cogsdk universal SDK: complete adk/ and cdk/ tiers in cogsdk repo, migrate all other repos to import cogsdk instead of private implementations

## Frequency
Stealth / Precision

## Outcome
cogsdk becomes the single source of truth for shared Go concerns across all CognitiveOS repos:

**In cogsdk repo:**
- `client/` tier already implemented (mcp, daemon, cpm, env) ✅ existing
- `adk/` tier implemented: agent, intent, memory, prompt packages with tests
- `cdk/` tier implemented: builder, cloudinit, target packages with tests
- All packages pass `go vet` and `go test`

**Across other repos (migrated to import cogsdk instead of private implementations):**
- `cognitiveosd/internal/daemon/` → uses cogsdk/client/daemon instead of raw_client.go/wide_client.go/socket.go
- `cpm/internal/daemon/client.go` → uses cogsdk/client/cpm instead of private daemon client
- `core-mcp-bridges/internal/mcp/` → uses cogsdk/client/mcp instead of private MCP server
- `cli/` → uses cogsdk/client/daemon instead of private socket client

All merged PRs follow GHW flow; all repos pass `go vet`; coordinated release tag `v1.1.3` created.

## Constraints

- All work MUST follow GHW: topic branch → PR → `development` → release PR → `main`
- No rebase MUST be used; plain `git pull` (merge) preferred
- All normative statements in spec updates MUST use RFC 2119 capitalized key words
- All Go code MUST pass `gofmt -s` and `go vet`
- All shell scripts MUST pass `sh -n` and `shellcheck`
- cogsdk must remain importable as `github.com/CognitiveOS-Project/cogsdk`
- ADR-011 MUST be followed: client/ tier is the only implemented tier; adk/ and cdk/ are staged → implemented
- cogsdk provides typed clients only — it never executes tools directly (ADR-004)
- All 16 repos MUST compile after migration

## Acceptance

- [ ] cogsdk/adk/agent implemented with tests
- [ ] cogsdk/adk/intent implemented with tests
- [ ] cogsdk/adk/memory implemented with tests
- [ ] cogsdk/adk/prompt implemented with tests
- [ ] cogsdk/cdk/builder implemented with tests
- [ ] cogsdk/cdk/cloudinit implemented with tests
- [ ] cogsdk/cdk/target implemented with tests
- [ ] cognitiveosd imports cogsdk/client/daemon instead of private raw_client.go/wide_client.go
- [ ] cpm imports cogsdk/client/cpm instead of internal/daemon/client.go
- [ ] core-mcp-bridges imports cogsdk/client/mcp instead of private MCP server code
- [ ] cli imports cogsdk/client/daemon instead of private socket client
- [ ] All PRs merged to `development`, then promoted to `main`
- [ ] `cognitiveos-alpine-distro` builds successfully with all repos using cogsdk
- [ ] Coordinated release tag `v1.1.2` created via `sdlc/scripts/release-tag.sh`
- [ ] All AGENTS.md enforcement references intact

## Verification

Run the Pilot's Final Checklist:

1. **Vibe Calibration** — Mission Script high-fidelity: poetic clarity + engineering precision. Frequency: Stealth/Precision.
2. **Garage Inspection** — MCP servers live. Privacy Shield active. HUD visible.
3. **Diamond Squad Roll Call** — 4 Specialists in position (Logic/Ops/Creative/Risk). Bridge is dead.
4. **Double Tenaza Grip** — Ready to Let Go (CI automated). Ready to Grip (telemetry triggers armed).
5. **Circuit Delta Target** — Baseline: 4 repos with private SDK code. Target: 0 repos with private SDK code.

IRA Target: 95%+. Below 70% triggers Vibe rewrite and re-run.

---
**Authority:** Pilot (VibeLeading)  
**Vocabulary:** SPECv1 (RFC 2119)  
**Workflow:** GHW (topic branch → PR → merge → development → PR → merge → main)  
**Synthesis:** ABSEv1 (AESE methodology via `WHAT` → `INIT`)