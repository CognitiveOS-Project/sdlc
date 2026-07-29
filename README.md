# CognitiveOS SDLC

Software Development Life Cycle documentation for the CognitiveOS project.

## What's here

| Path | Description |
|------|-------------|
| [`plan/implementation-plan.md`](plan/implementation-plan.md) | Full build plan with phases, dependencies, and deliverables |
| [`plan/boot-startup-analysis.md`](plan/boot-startup-analysis.md) | Boot/startup lifecycle implementation plan — phases, deliverables, verification |
| [`plan/boot-flow-verification.md`](plan/boot-flow-verification.md) | Boot flow verification plan — step-by-step test procedures for ISO and Docker |
| [`plan/milestones.md`](plan/milestones.md) | Milestone tracking and progress |
| [`workflow/contribution-guide.md`](workflow/contribution-guide.md) | How to contribute to CognitiveOS repos |
| [`workflow/code-review.md`](workflow/code-review.md) | Code review standards and checklist |
| [`workflow/testing.md`](workflow/testing.md) | Testing strategy across all layers |
| [`workflow/ci-cd.md`](workflow/ci-cd.md) | CI/CD pipeline definitions |
| [`product-specs/specs/`](https://github.com/CognitiveOS-Project/product-specs/tree/main/specs) | Coding standards, protocol definitions, and specifications |

Architecture Decision Records and specifications live in [product-specs](https://github.com/CognitiveOS-Project/product-specs) (`adr/` and `specs/`).

## Implementation Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | CPM core (init, install, list, search, verify, update) | ✅ |
| 1b | CPM gap closure (pack, download-weights, deps, config, schema) | ✅ |
| 1c | Auth system (signup, login, register, key fallback) | ✅ |
| 1d | Web UI (GitHub OAuth, dashboard, key management) | ✅ |
| 1e | Publish gating & unlock codes | ✅ |
| 2 | Hardware bridges (MCP servers) | ✅ |
| 2b | Bridge spec compliance | ✅ |
| 3 | Inference engine (Ollama-compatible API) | ~90% |
| 3b | Inference spec compliance | ✅ |
| 4 | System daemon (cognitiveosd) | ~95% |
| 4b | Daemon spec compliance | ✅ |
| 5 | CLI/TUI | ~85% |
| 5b | CLI spec compliance | ~70% |
| 6 | Distribution image (Alpine) | ✅ |
| 6b | coginit PID 1 (unified boot) | ✅ |
| 7 | Registry & ecosystem | ✅ |
| 8 | Autonomous package management | Partially spec'd |

## Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Core CPM + registry bootstrap | ✅ |
| M1 | Inference engine + MCP bridges | ✅ |
| M1b | Registry server (S3, SSH auth, notary) | ✅ |
| M2 | System daemon + CLI/TUI | ✅ |
| M2b | Web UI + auth system | ✅ |
| M3 | Distribution image + coginit | ✅ |
| M4 | Registry ecosystem (schemas, gates, unlock) | ✅ |
| M5 | Hardware bridges spec compliance | ✅ |
| M6 | Inference spec compliance | ✅ |
| M7 | CLI spec compliance | In progress |

See `plan/milestones.md` for detailed deliverables and timeline.

## Related

- [CognitiveOS](https://github.com/CognitiveOS-Project/cognitiveos) — main project repository
- [cognitive-os.org](https://cognitive-os.org) — project website
- [coginit](https://github.com/CognitiveOS-Project/coginit) — boot manager
- [Product Specs](https://github.com/CognitiveOS-Project/product-specs) — standards, schemas, and protocol definitions
- [CognitiveOS Project](https://github.com/CognitiveOS-Project) — GitHub organization

## Contributing

Read the guides in `workflow/` before submitting changes:

- [`workflow/contribution-guide.md`](workflow/contribution-guide.md) — full contribution process
- [`workflow/code-review.md`](workflow/code-review.md) — review checklist and expectations
- [`workflow/testing.md`](workflow/testing.md) — testing strategy across all layers
- [`workflow/ci-cd.md`](workflow/ci-cd.md) — CI/CD pipeline definitions

All repos follow the git workflow defined in root `.opencode/instructions/git-workflow.md`:

1. Branch from `development`, not `main`
2. Use topic branches: `feature/<name>`, `fix/<name>`, `bugfix/<name>`
3. Open a PR to `development` with a clear title and description
4. Merge via squash after review
5. Changes flow to `main` via a release PR

## Author

**Jean Machuca** — [GitHub](https://github.com/jeanmachuca) · [Sponsor](https://github.com/sponsors/jeanmachuca)
