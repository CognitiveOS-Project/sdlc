# Contribution Guide

## Getting Started

1. Pick a repo from the [CognitiveOS-Project](https://github.com/CognitiveOS-Project) org
2. Read its `AGENTS.md` for repo-specific build instructions
3. Read the relevant spec in [product-specs](https://github.com/CognitiveOS-Project/product-specs)
4. Find an open issue or create one describing what you want to work on

## Branching — Per-Repo, Scoped GHW Flow

All repos follow the same **per-repo scoped** workflow. Complete the full cycle for one repo before moving to the next:

```bash
git fetch origin
git checkout -b feature/<short-description> development   # branch from development, not main
# make changes
git add .
git commit -m "<type>: <description>"
git push -u origin HEAD
```

**Rules:**
1. One repo at a time. Do not switch to another repo until the PR cycle is fully merged to `main`.
2. Branch from `development`, not `main`.
3. No `git rebase`. Use `git pull` (merge) to update from remote.
4. Commit types: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
5. Direct push to `main` or `development` is prohibited except on explicit user instruction (maintainer emergency).

## Pull Request Process — Full Cycle Per Repo

Do not open the next repo's PR until this repo's cycle is complete:

1. **Topic branch → `development`**: Open a PR from your topic branch into `development`.
2. **Wait for CI**: Check that all CI checks pass on the PR (shellcheck, go vet, lint, tests).
3. **Fix CI failures**: If CI fails, push fixes to the same topic branch and re-check.
4. **Merge to `development`**: Squash merge only after CI is green.
5. **`development` → `main` (release PR)**: Open a PR from `development` into `main`.
6. **Wait for CI**: Check CI passes on the release PR.
7. **Merge to `main`**: Only merge after CI is green.
8. **Verify sync**: Confirm `main` == `development` locally before moving to the next repo.

**No orphan topic branches:** Every pushed branch must have an open PR, and every open PR must be merged or closed before switching repos.

Commit types:
- `feat:` — New feature
- `fix:` — Bug fix
- `chore:` — Maintenance, tooling, config
- `docs:` — Documentation
- `refactor:` — Code change with no behavior change
- `test:` — Adding or updating tests

## Code Standards

### Go
- Follow `gofmt` (the Go standard)
- Run `gofmt -s -w .` before committing
- Follow standard Go project layout (`cmd/`, `internal/`, `pkg/`)
- Use `CGO_ENABLED=0` for static binaries
- All errors must be handled or explicitly ignored (`_ = fn()`)

### Shell
- Use `shellcheck` for bash scripts
- Prefer POSIX `sh` over bash-specific features

### Markdown
- Wrap lines at 80 characters
- Use `-` for unordered lists, `1.` for ordered
- Code blocks must specify language

## Pull Request Process

1. Title: `<type>: <short description>` (e.g., `feat: add cpm install command`)
2. Description: What, why, how. Reference the spec section if applicable.
3. Ensure all checks pass (lint, test)
4. Request review from a maintainer
5. Squash merge to `main`

## Testing

- All new Go code should have unit tests
- Integration tests go in `tests/` at repo root
- Run `go test ./...` before pushing
- For cross-repo changes, note the dependency in the PR description

## Communication

- Use GitHub Issues for feature requests and bug reports
- Use GitHub Discussions for design discussions
- Reference spec documents from product-specs when relevant
