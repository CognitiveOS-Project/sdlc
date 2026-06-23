# Code Review Standards

## Review Checklist

Every PR must pass these checks before merging:

### Correctness
- [ ] Does the code do what the spec says?
- [ ] Are edge cases handled (empty input, missing files, network errors)?
- [ ] Are errors returned and not silently swallowed?
- [ ] Are there no data races (Go: `-race` flag)?

### Architecture
- [ ] Does it follow the CognitiveOS architecture (as defined in product-specs)?
- [ ] Are the right components talking to each other in the right way?
- [ ] Does it use the defined APIs (daemon socket, MCP protocol, etc.)?

### Security
- [ ] Are file paths sanitized?
- [ ] Are cgroup limits applied where relevant?
- [ ] Does it assume root? (acceptable — CognitiveOS is single-user)
- [ ] Does it open any network ports? (should not, outside of registry-server and inference)

### Style
- [ ] `gofmt -s` has been run
- [ ] No commented-out code
- [ ] Meaningful variable names (not `x`, `tmp`, `data`)
- [ ] No magic numbers (use named constants)
- [ ] Log messages are clear and include relevant context

### Testing
- [ ] Unit tests for new functions
- [ ] Integration tests for new components
- [ ] Tests run and pass (`go test ./...`)

## Review Process

1. **Author** opens PR with clear description
2. **Reviewer** runs through checklist above
3. **Reviewer** leaves comments inline or approves
4. **Author** addresses feedback or explains why it's not needed
5. **Reviewer** approves
6. **Author** merges (squash merge to `development`)

### Time Expectations

- Small PR (< 100 lines): review within 24 hours
- Medium PR (100-500 lines): review within 48 hours
- Large PR (> 500 lines): review within 72 hours (consider splitting)

## What Good Review Looks Like

```
Looks good overall. A few comments:

1. File: internal/install.go:45 — This error is swallowed. 
   Should propagate or log.

2. File: internal/audit.go:22 — This magic number should be a 
   named const (see filesystem-hierarchy spec for the value).

3. File: cmd/cpm/main.go:10 — Nice use of the hardware audit 
   interface. Clean separation.
```

## What Bad Review Looks Like

```
LGTM
```
