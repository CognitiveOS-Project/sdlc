# Contribution Guide

## Getting Started

1. Pick a repo from the [CognitiveOS-Project](https://github.com/CognitiveOS-Project) org
2. Read its `AGENTS.md` for repo-specific build instructions
3. Read the relevant spec in [product-specs](https://github.com/CognitiveOS-Project/product-specs)
4. Find an open issue or create one describing what you want to work on

## Branching

All repos follow the same workflow:

```bash
git fetch origin
git checkout -b feature/<short-description> development
# make changes
git add .
git commit -m "<type>: <description>"
git push -u origin HEAD
```

Create a PR into `development`. See the root `AGENTS.md` and `.opencode/instructions/git-workflow.md` in the workspace root for full details.

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
5. Squash merge to `development`

## Testing

- All new Go code should have unit tests
- Integration tests go in `tests/` at repo root
- Run `go test ./...` before pushing
- For cross-repo changes, note the dependency in the PR description

## Communication

- Use GitHub Issues for feature requests and bug reports
- Use GitHub Discussions for design discussions
- Reference spec documents from product-specs when relevant
