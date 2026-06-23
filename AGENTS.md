# CognitiveOS SDLC

This repo defines **how we build** CognitiveOS. It is the process layer above the technical specs in product-specs.

## Key documents

- `plan/implementation-plan.md` — Full build plan with phases, dependencies, deliverables
- `plan/milestones.md` — Milestone tracking (M0–M7)
- `workflow/contribution-guide.md` — How to contribute, commit conventions, PR flow
- `workflow/code-review.md` — Review checklist and expectations
- `workflow/testing.md` — Testing strategy (unit → integration → hardware → boot)
- `workflow/ci-cd.md` — CI/CD pipeline definitions for all repos
- `adr/` — Architecture Decision Records

## Rules

- All repos follow the git workflow defined in root `.opencode/instructions/git-workflow.md`
- Branch from `development`, PR to `development`, no rebase
- Commit types: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
- Go code must pass `gofmt -s` and `go vet`
