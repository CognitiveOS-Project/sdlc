# CI/CD Pipeline

## Overview

Each CognitiveOS repo has its own CI pipeline defined in `.github/workflows/`. This document defines the standard pipeline template that every repo should implement.

## Standard CI Workflow

File: `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main, development]
  pull_request:
    branches: [development]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go fmt ./...
      - run: go vet ./...

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go test -race ./...

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: CGO_ENABLED=0 go build ./cmd/...
```

## Repo-Specific Additions

### cpm — Package Integration Tests
```yaml
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
      - run: go test ./tests/...
```

### core-mcp-bridges — Cross-Compile Check
```yaml
  cross-compile:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        goos: [linux]
        goarch: [amd64, arm64]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
      - run: CGO_ENABLED=0 GOOS=${{ matrix.goos }} GOARCH=${{ matrix.goarch }} go build ./cmd/...
```

### cognitiveos-distro — Full Build Test
```yaml
  build-iso:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make iso
      - uses: actions/upload-artifact@v4
        with:
          name: cognitiveos-iso
          path: output/*.iso
```

## Release Workflow (Per Repo)

File: `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
      - run: CGO_ENABLED=0 go build ./cmd/...
      - uses: softprops/action-gh-release@v2
        with:
          files: |
            cognitiveos-*.iso
            cognitiveos-*.img
```

## Coordinated Release (Cross-Repo)

At the end of a release cycle, all 13 repos must be tagged at the same SemVer version. Use the `release-tag.sh` script:

```bash
scripts/release-tag.sh v1.0.0-alpha "v1.0.0-alpha — System foundations complete"
```

The script:
- Clones each repo on demand into a persistent cache directory
- Creates **annotated tags** (compliant with release-strategy.md)
- Skips repos where the tag already exists (idempotent)
- Reports per-repo status in a summary table
- Exits non-zero if any repo fails

### Manual Trigger (GitHub Actions)

File: `.github/workflows/coordinated-release.yml`

```yaml
name: Coordinated Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'SemVer tag (e.g. v1.0.0-alpha)'
        required: true
      message:
        description: 'Tag message'
        required: true
        default: 'CognitiveOS coordinated release'

jobs:
  tag:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: scripts/release-tag.sh "${{ inputs.version }}" "${{ inputs.message }}"
        env:
          COGNITIVEOS_RELEASE_DIR: /tmp/cognitiveos-releases
```

## Status Badges

Each repo README should include:

```markdown
[![CI](https://github.com/CognitiveOS-Project/<repo>/workflows/CI/badge.svg)](https://github.com/CognitiveOS-Project/<repo>/actions)
```

## Runner Requirements

| Test type | Runner | Notes |
|-----------|--------|-------|
| Lint, unit, build | Standard GitHub runner | ubuntu-latest |
| Integration | Standard GitHub runner | May need `sudo` for some socket tests |
| Cross-compile | Standard GitHub runner | Go cross-compile is native |
| Full ISO build | GitHub runner + Docker | 16 GB+ free disk |
| Hardware tests | Self-hosted (RPi, laptop) | Manual trigger only |
