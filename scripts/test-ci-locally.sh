#!/bin/sh
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

pass=0
fail=0
skip=0
report=""

check() {
  local name="$1"
  local status="$2"
  local detail="$3"
  case "$status" in
    pass) report="${report}  [PASS] ${name}${detail:+ — ${detail}}\n"; pass=$((pass+1)) ;;
    fail) report="${report}  [${RED}FAIL${NC}] ${name}${detail:+ — ${detail}}\n"; fail=$((fail+1)) ;;
    skip) report="${report}  [${YELLOW}SKIP${NC}] ${name}${detail:+ — ${detail}}\n"; skip=$((skip+1)) ;;
  esac
}

section() {
  report="${report}\n${BOLD}── $1 ──${NC}\n"
}

tool_check() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
}

hr() {
  report="${report}----------------------------------------\n"
}

# ── preamble ──
report="${BOLD}CI Local Test Report${NC}\n"
report="${report}$(date)\n"
report="${report}Host: $(uname -a)\n"
hr

# ── Tool availability ──
section "Tool Availability"
for tool in go shellcheck docker golangci-lint sh git; do
  if command -v "$tool" >/dev/null 2>&1; then
    ver=$("$tool" version 2>&1 | head -1)
    check "$tool" pass "$ver"
  else
    check "$tool" skip "not installed"
  fi
done
hr

# ── Inference repo checks ──
section "Inference Repo (cmd/coginfer + cmd/cograw)"
INFER="/workspace/inference"
if [ -d "$INFER" ]; then
  # Go build (CGO_ENABLED=0)
  if command -v go >/dev/null 2>&1; then
    if CGO_ENABLED=0 go build -o /dev/null ./cmd/coginfer 2>&1; then
      check "go build ./cmd/coginfer (CGO_ENABLED=0)" pass
    else
      check "go build ./cmd/coginfer (CGO_ENABLED=0)" fail "build error"
    fi

    if CGO_ENABLED=0 go build -o /dev/null ./cmd/cograw 2>&1; then
      check "go build ./cmd/cograw (CGO_ENABLED=0)" pass
    else
      check "go build ./cmd/cograw (CGO_ENABLED=0)" fail "build error"
    fi

    if go vet ./... 2>&1; then
      check "go vet ./..." pass
    else
      check "go vet ./..." fail "vet errors"
    fi

    if go test ./... -count=1 2>&1; then
      check "go test ./..." pass
    else
      check "go test ./..." fail "test failures"
    fi
  else
    check "go build ./cmd/coginfer (CGO_ENABLED=0)" skip "go not installed"
    check "go build ./cmd/cograw (CGO_ENABLED=0)" skip "go not installed"
    check "go vet ./..." skip "go not installed"
    check "go test ./..." skip "go not installed"
  fi

  # golangci-lint
  if command -v golangci-lint >/dev/null 2>&1; then
    if golangci-lint run --timeout=3m ./... 2>&1; then
      check "golangci-lint" pass
    else
      check "golangci-lint" fail "lint errors"
    fi
  else
    check "golangci-lint" skip "not installed"
  fi

  # Git diff check (uncommitted changes)
  if [ -n "$(git -C "$INFER" status --porcelain)" ]; then
    check "git status clean" fail "uncommitted changes in inference repo"
  else
    check "git status clean" pass
  fi

  # Verify CGo files have correct build tags
  for f in bridge.go cgobackend.go; do
    if [ -f "$INFER/internal/llm/$f" ]; then
      if head -1 "$INFER/internal/llm/$f" | grep -q 'cgo'; then
        check "build tag cgo on $f" pass
      else
        check "build tag cgo on $f" fail "missing //go:build cgo"
      fi
    fi
  done
  for f in cograw_llm.go; do
    if [ -f "$INFER/cmd/cograw/$f" ]; then
      if head -1 "$INFER/cmd/cograw/$f" | grep -q 'cgo'; then
        check "build tag cgo on $f" pass
      else
        check "build tag cgo on $f" fail "missing //go:build cgo"
      fi
    fi
  done
  for f in cograw_stub.go backend_stub.go; do
    if [ -f "$INFER/cmd/cograw/$f" ]; then
      if head -1 "$INFER/cmd/cograw/$f" | grep -q '!cgo'; then
        check "build tag !cgo on $f" pass
      else
        check "build tag !cgo on $f" fail "missing //go:build !cgo"
      fi
    fi
    if [ -f "$INFER/internal/server/$f" ]; then
      if head -1 "$INFER/internal/server/$f" | grep -q '!cgo'; then
        check "build tag !cgo on $f" pass
      else
        check "build tag !cgo on $f" fail "missing //go:build !cgo"
      fi
    fi
  done

  # Verify no llamaBin/CLIBackend references remain
  if grep -qr 'llamaBin\|CLIBackend\|llama-cli' "$INFER" --include='*.go' 2>/dev/null; then
    check "no llamaBin/CLIBackend/llama-cli in .go files" fail "stale references found"
  else
    check "no llamaBin/CLIBackend/llama-cli in .go files" pass
  fi
else
  check "inference repo exists" skip "not found at $INFER"
fi
hr

# ── CognitiveOS-Distro checks ──
section "CognitiveOS-Distro Repo"
DISTRO="/workspace/cognitiveos-distro"
if [ -d "$DISTRO" ]; then
  # Shell syntax check
  script_errors=0
  for script in "$DISTRO"/scripts/*.sh; do
    name=$(basename "$script")
    if sh -n "$script" 2>/dev/null; then
      check "sh -n $name" pass
    else
      check "sh -n $name" fail "syntax error"
      script_errors=$((script_errors+1))
    fi
  done
fi

# shellcheck
if command -v shellcheck >/dev/null 2>&1; then
  if [ -d "$DISTRO" ]; then
    for script in "$DISTRO"/scripts/*.sh; do
      name=$(basename "$script")
      if shellcheck -s sh -S warning "$script" 2>&1; then
        check "shellcheck $name" pass
      else
        check "shellcheck $name" fail "warnings found"
      fi
    done
  fi
else
  check "shellcheck" skip "not installed"
fi

# Git status
if [ -d "$DISTRO" ] && [ -n "$(git -C "$DISTRO" status --porcelain)" ]; then
  check "git status clean" fail "uncommitted changes in cognitiveos-distro"
elif [ -d "$DISTRO" ]; then
  check "git status clean" pass
fi

# Dockerfile syntax check (basic)
if [ -f "$DISTRO/docker/Dockerfile.build" ]; then
  if grep -q '^FROM ' "$DISTRO/docker/Dockerfile.build" 2>/dev/null; then
    check "Dockerfile.build has FROM" pass
  else
    check "Dockerfile.build has FROM" fail "missing FROM instruction"
  fi
fi

# Verify HTTPS not used in Dockerfile
if [ -f "$DISTRO/docker/Dockerfile.build" ]; then
  if grep -q 'https://github.com' "$DISTRO/docker/Dockerfile.build" 2>/dev/null; then
    check "Dockerfile.build uses SSH (not HTTPS)" fail "HTTPS clone found"
  else
    check "Dockerfile.build uses SSH (not HTTPS)" pass
  fi
fi

# Verify cograw is built in scripts
if [ -f "$DISTRO/scripts/build-binaries.sh" ]; then
  if grep -q 'cograw' "$DISTRO/scripts/build-binaries.sh" 2>/dev/null; then
    check "build-binaries.sh builds cograw" pass
  else
    check "build-binaries.sh builds cograw" fail "cograw target not found"
  fi
  if grep -q 'CGO_ENABLED=1' "$DISTRO/scripts/build-binaries.sh" 2>/dev/null; then
    check "build-binaries.sh uses CGO_ENABLED=1" pass
  else
    check "build-binaries.sh uses CGO_ENABLED=1" fail "CGO_ENABLED=1 not found"
  fi
fi
hr

# ── Cross-repo consistency ──
section "Cross-Repo Consistency"

# Check that both repos are on development branch
for dir in inference cognitiveos-distro; do
  branch=$(git -C "/workspace/$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
  if [ "$branch" = "development" ]; then
    check "$dir on development branch" pass
  else
    check "$dir on development branch" fail "on $branch"
  fi
done

# Check that v0.4.0 tag exists on both remotes
for dir in inference cognitiveos-distro; do
  if git -C "/workspace/$dir" tag -l 'v0.4.0' 2>/dev/null | grep -q .; then
    check "$dir has v0.4.0 tag" pass
  else
    if git -C "/workspace/$dir" fetch origin --tags 2>/dev/null && \
       git -C "/workspace/$dir" tag -l 'v0.4.0' 2>/dev/null | grep -q .; then
      check "$dir has v0.4.0 tag" pass
    else
      check "$dir has v0.4.0 tag" fail "tag v0.4.0 not found locally or on remote"
    fi
  fi
done
hr

# ── Summary ──
report="${report}\n${BOLD}Summary${NC}\n"
report="${report}  Pass: ${GREEN}${pass}${NC}\n"
report="${report}  Fail: ${RED}${fail}${NC}\n"
report="${report}  Skip: ${YELLOW}${skip}${NC}\n"
report="${report}  Total: $((pass+fail+skip))\n"

# Print report
printf "%b\\n" "$report" >&2

# Write report to file
REPORT_DIR="/workspace/test-reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="${REPORT_DIR}/ci-local-report-$(date +%Y%m%d-%H%M%S).txt"
printf "%b\\n" "$report" > "$REPORT_FILE"
echo "Report written to $REPORT_FILE"

# Exit with non-zero if any failures
[ "$fail" -eq 0 ]
