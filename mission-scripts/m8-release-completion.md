# Mission Script: M8 Release Completion

## Mission Name
M8 Release Completion — produce `v1.1.0-alpha` variant assets and close M8 checkboxes

## Frequency
Stealth / Precision

## Outcome
All five `v1.1.0-alpha` variant release pipelines (edge-armv7, edge-aarch64, gateway-x86_64, standard-x86_64, micro-armv7) complete successfully with assets attached to the GitHub Release `v1.1.0-alpha`. M8 milestone marked fully complete. No variant asset is missing.

## Constraints

- Variants MUST build without `make: not found` (fixed via `MKIMAGE_DEPS` addition in `build-image.sh`).
- Variants MUST clone aports without HTTP 418 from GitLab (fixed via `APORTS_GIT` GitHub mirror in `build-image.sh`).
- Variants MUST use `install-build-deps.sh` with script-location-derived paths (fixed via `REPO_DIR`/`OVERLAY_DIR`/`CPM_BIN` derivation).
- The `release.yml` aggregator MUST attach all variant assets to the GitHub Release.
- Titan variant MUST remain manual-only (existing policy).
- All changes MUST follow GHW: topic branch → PR → `development` → release PR → `main`.
- All normative statements in spec updates MUST use RFC 2119 capitalized key words.

## Acceptance

- [ ] All five variant pipelines green on `v1.1.0-alpha` tag push
- [ ] All five variant assets (ISO + tarball + SHA256SUMS per class/arch) present in GitHub Release `v1.1.0-alpha`
- [ ] M8 milestone in `plan/milestones.md` marked fully complete (no remaining `[ ]` items)
- [ ] `sdlc/scripts/release-tag.sh` verified as the canonical tagging path
- [ ] `sdlc/scripts/healthcheck.sh` verified green across all 16 repos

## Verification

Run the Pilot's Final Checklist:

1. **Vibe Calibration** — Mission Script is high-fidelity: poetic clarity + engineering precision. Frequency is Stealth/Precision.
2. **Garage Inspection** — MCP servers live. Privacy Shield active. HUD visible.
3. **Diamond Squad Roll Call** — 4 Specialists in position (Logic/Ops/Creative/Risk). Bridge is dead.
4. **Double Tenaza Grip** — Ready to Let Go (CI automated). Ready to Grip (telemetry triggers armed for variant failures).
5. **Circuit Delta Target** — Baseline: variant pipelines previously failed on CI infra. Target: zero failed variant assets.

IRA Target: 95%+. Below 70% triggers Vibe rewrite and re-run.

---
**Authority:** Pilot (VibeLeading)  
**Vocabulary:** SPECv1 (RFC 2119)  
**Workflow:** GHW (topic branch → PR → merge → development → PR → merge → main)