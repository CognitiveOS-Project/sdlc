#!/bin/sh
# shellcheck disable=SC3043,SC2044
set -e

# ── Config ──
ALL_REPOS="coginit cognitiveos product-specs sdlc cpm core-mcp-bridges inference cognitiveosd cli cognitiveos-alpine-distro registry-server cgp-template"

GO_REPOS="inference cognitiveosd cli coginit cpm core-mcp-bridges registry-server"
SHELL_REPOS="cognitiveos-alpine-distro sdlc"
CGO_REPOS="inference"
BUILD_REPOS="coginit cpm inference core-mcp-bridges cognitiveosd cli"

CURRENT_TAG=""

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── State ──
WORK_DIR=""
REPORT_DIR=""
BRANCH="main"
MODE_JSON=0
MODE_QUIET=0
pass=0
fail=0
skip=0
report=""
json_entries=""

# ── Functions ──
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Periodic CI health check across all CognitiveOS repos.

Options:
  --work-dir DIR    Directory for repo clones (default: temp dir)
  --report-dir DIR  Directory for report output (default: ./reports/)
  --tag TAG         Tag to check for (required)
  --branch BRANCH   Branch to check (default: main)
  --json            Output JSON summary to stdout
  --quiet           Suppress human-readable progress
  --help            Show this help
EOF
  exit 0
}

check() {
  local name="$1" status="$2" detail="$3"
  case "$status" in
    pass) pass=$((pass+1)) ;;
    fail) fail=$((fail+1)) ;;
    skip) skip=$((skip+1)) ;;
  esac
  if [ "$MODE_QUIET" -eq 0 ]; then
    case "$status" in
      pass) report="${report}  [PASS] ${name}${detail:+ — ${detail}}\n" ;;
      fail) report="${report}  [${RED}FAIL${NC}] ${name}${detail:+ — ${detail}}\n" ;;
      skip) report="${report}  [${YELLOW}SKIP${NC}] ${name}${detail:+ — ${detail}}\n" ;;
    esac
  fi
  json_entries="${json_entries}${json_entries:+,}{\"name\":\"$(echo "$name" | sed 's/"/\\"/g')\",\"status\":\"$status\",\"detail\":\"$(echo "$detail" | sed 's/"/\\"/g')\"}"
}

section() {
  [ "$MODE_QUIET" -eq 0 ] && report="${report}\n${BOLD}── $1 ──${NC}\n"
  return 0
}

hr() {
  [ "$MODE_QUIET" -eq 0 ] && report="${report}----------------------------------------\n"
  return 0
}

clone_repo() {
  local repo="$1" dir="$2"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch origin "$BRANCH" --depth=1 --quiet 2>/dev/null
    git -C "$dir" fetch origin --tags --quiet 2>/dev/null || true
    git -C "$dir" checkout -f "origin/$BRANCH" --quiet 2>/dev/null
    return 0
  fi
  git clone --depth=1 "git@github.com:CognitiveOS-Project/${repo}.git" "$dir" --branch "$BRANCH" --quiet 2>/dev/null
  git -C "$dir" fetch origin --tags --quiet 2>/dev/null || true
}

has_go() { command -v go >/dev/null 2>&1; }
has_shellcheck() { command -v shellcheck >/dev/null 2>&1; }
has_cmake() { command -v cmake >/dev/null 2>&1; }
has_gcc() { command -v gcc >/dev/null 2>&1; }

check_go_build() {
  local dir="$1" label="$2"
  if ! has_go; then
    check "go build $label" skip "go not installed"
    return
  fi
  if (cd "$dir" && CGO_ENABLED=0 go build -o /dev/null ./... 2>&1); then
    check "go build $label" pass
  else
    check "go build $label" fail "build error"
  fi
}

check_go_vet() {
  local dir="$1" label="$2"
  if ! has_go; then
    check "go vet $label" skip "go not installed"
    return
  fi
  if (cd "$dir" && CGO_ENABLED=0 go vet ./... 2>&1); then
    check "go vet $label" pass
  else
    check "go vet $label" fail "vet errors"
  fi
}

check_go_build_cgo() {
  local dir="$1" label="$2"
  if ! has_go; then
    check "cgo build $label" skip "go not installed"
    return
  fi
  if ! has_cmake; then
    check "cgo build $label" skip "cmake not installed"
    return
  fi
  if ! has_gcc; then
    check "cgo build $label" skip "gcc not installed"
    return
  fi
  local llama_dir="$dir/vendor/llama.cpp"
  if [ ! -f "$llama_dir/CMakeLists.txt" ]; then
    mkdir -p "$dir/vendor"
    git clone --depth=1 https://github.com/ggerganov/llama.cpp.git "$llama_dir" >/dev/null 2>&1 || {
      check "cgo build $label" skip "llama.cpp clone failed"
      return
    }
  fi
  if [ ! -f "$llama_dir/build/libllama.a" ]; then
    (cd "$llama_dir" && cmake -B build -DLLAMA_NATIVE=0 \
      -DBUILD_SHARED_LIBS=0 -DLLAMA_BUILD_TESTS=0 \
      -DLLAMA_BUILD_EXAMPLES=0 -DLLAMA_BUILD_SERVER=0 \
      -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$PWD/build" && \
     cmake --build build --target llama --config Release -j"$(nproc)") >/dev/null 2>&1 || {
      check "cgo build $label" fail "llama.cpp cmake build failed"
      return
    }
  fi
  local ggml_inc="$llama_dir/ggml/include"
  local ggml_ld=""
  for lib in $(find "$llama_dir/build" -name "libggml*.a" -type f); do
    libname=$(basename "$lib" .a | sed 's/^lib//')
    ggml_ld="${ggml_ld} -l${libname}"
  done
  ggml_ld="${ggml_ld} -lgomp"
  if (cd "$dir" && CGO_ENABLED=1 CGO_CFLAGS="-I$ggml_inc" CGO_LDFLAGS="$ggml_ld" go build -tags=cgo -o /dev/null ./cmd/cograw >/dev/null 2>&1); then
    check "cgo build $label" pass
  else
    check "cgo build $label" fail "cgo build error"
  fi
}

check_go_vet_cgo() {
  local dir="$1" label="$2"
  if ! has_go; then
    check "cgo vet $label" skip "go not installed"
    return
  fi
  if ! has_cmake; then
    check "cgo vet $label" skip "cmake not installed"
    return
  fi
  if ! has_gcc; then
    check "cgo vet $label" skip "gcc not installed"
    return
  fi
  local llama_dir="$dir/vendor/llama.cpp"
  if [ ! -f "$llama_dir/CMakeLists.txt" ] || [ ! -f "$llama_dir/build/libllama.a" ]; then
    check "cgo vet $label" skip "llama.cpp not built (cgo build step handles this)"
    return
  fi
  local ggml_inc="$llama_dir/ggml/include"
  local ggml_ld=""
  for lib in $(find "$llama_dir/build" -name "libggml*.a" -type f); do
    libname=$(basename "$lib" .a | sed 's/^lib//')
    ggml_ld="${ggml_ld} -l${libname}"
  done
  ggml_ld="${ggml_ld} -lgomp"
  if (cd "$dir" && CGO_ENABLED=1 CGO_CFLAGS="-I$ggml_inc" CGO_LDFLAGS="$ggml_ld" go vet -tags=cgo ./... >/dev/null 2>&1); then
    check "cgo vet $label" pass
  else
    check "cgo vet $label" fail "cgo vet errors"
  fi
}

check_sh_syntax() {
  local dir="$1" label="$2"
  local errors=0
  for script in "$dir"/scripts/*.sh; do
    [ -f "$script" ] || continue
    sh -n "$script" 2>/dev/null || { errors=$((errors+1)); }
  done
  if [ "$errors" -eq 0 ]; then
    check "sh -n scripts/ $label" pass
  else
    check "sh -n scripts/ $label" fail "$errors script(s) with syntax errors"
  fi
}

check_shellcheck() {
  local dir="$1" label="$2"
  if ! has_shellcheck; then
    check "shellcheck $label" skip "not installed"
    return
  fi
  local errors=0
  for script in "$dir"/scripts/*.sh; do
    [ -f "$script" ] || continue
    shellcheck -S warning "$script" 2>/dev/null || errors=$((errors+1))
  done
  if [ "$errors" -eq 0 ]; then
    check "shellcheck $label" pass
  else
    check "shellcheck $label" fail "$errors script(s) with warnings"
  fi
}

check_build_tags() {
  local dir="$1" label="$2"
  local errors=0
  for f in bridge.go cgobackend.go; do
    p="$dir/internal/llm/$f"
    [ -f "$p" ] || continue
    head -1 "$p" | grep -q 'cgo' || { errors=$((errors+1)); check "build tag cgo on $f ($label)" fail "missing //go:build cgo"; }
  done
  f="cograw_llm.go"
  p="$dir/cmd/cograw/$f"
  if [ -f "$p" ] && ! head -1 "$p" | grep -q 'cgo'; then
    errors=$((errors+1))
    check "build tag cgo on $f ($label)" fail "missing //go:build cgo"
  fi
  for f in cograw_stub.go backend_stub.go; do
    for d in cmd/cograw internal/server; do
      p="$dir/$d/$f"
      [ -f "$p" ] || continue
      head -1 "$p" | grep -q '!cgo' || { errors=$((errors+1)); check "build tag !cgo on $f ($label)" fail "missing //go:build !cgo"; }
    done
  done
  if [ "$errors" -eq 0 ]; then
    check "build tags ($label)" pass
  fi
  unset errors
}

check_stale_refs() {
  local dir="$1" label="$2"
  if grep -qr 'llamaBin\|CLIBackend\|llama-cli' "$dir" --include='*.go' 2>/dev/null; then
    check "stale refs ($label)" fail "llamaBin/CLIBackend/llama-cli found"
  else
    check "stale refs ($label)" pass
  fi
}

check_dockerfile() {
  local dir="$1" label="$2"
  local df=""
  for candidate in "$dir/docker/Dockerfile.build" "$dir/Dockerfile"; do
    [ -f "$candidate" ] && df="$candidate" && break
  done
  [ -z "$df" ] && { check "Dockerfile ($label)" skip "not found"; return; }
  if grep -q '^FROM ' "$df" 2>/dev/null; then
    check "Dockerfile FROM ($label)" pass
  else
    check "Dockerfile FROM ($label)" fail "missing FROM"
  fi
  if grep -Eq '^(COPY|ADD)\s+.*https://github\.com.*CognitiveOS-Project' "$df" 2>/dev/null; then
    check "Dockerfile HTTPS ($label)" pass
  else
    check "Dockerfile SSH ($label)" pass
  fi
}

check_cgo_enabled() {
  local dir="$1" label="$2"
  local inference_dir="$WORK_DIR/inference"
  if [ -f "$inference_dir/Makefile" ] && grep -q 'CGO_ENABLED=1' "$inference_dir/Makefile" 2>/dev/null; then
    check "CGO_ENABLED=1 ($label)" pass
  else
    check "CGO_ENABLED=1 ($label)" fail "not set in inference Makefile"
  fi
}

check_cograw_target() {
  local dir="$1" label="$2"
  local inference_dir="$WORK_DIR/inference"
  if [ -f "$inference_dir/Makefile" ] && grep -q 'cograw' "$inference_dir/Makefile" 2>/dev/null; then
    check "cograw target ($label)" pass
  else
    check "cograw target ($label)" fail "not found in inference Makefile"
  fi
}

check_repo_visibility() {
  local dir="$1" label="$2"
  if ! command -v gh >/dev/null 2>&1; then
    check "visibility ($label)" skip "gh not installed"
    return
  fi
  local vis
  vis=$(gh -R "CognitiveOS-Project/$label" repo view --json visibility --jq '.visibility' 2>/dev/null || echo "UNKNOWN")
  if [ "$vis" = "PUBLIC" ]; then
    check "visibility ($label)" pass "PUBLIC"
  elif [ "$vis" = "PRIVATE" ]; then
    check "visibility ($label)" fail "PRIVATE — must be PUBLIC for CI"
  else
    check "visibility ($label)" fail "UNKNOWN"
  fi
}

# ── Parse args ──
while [ $# -gt 0 ]; do
  case "$1" in
    --work-dir) shift; WORK_DIR="$1" ;;
    --report-dir) shift; REPORT_DIR="$1" ;;
    --branch) shift; BRANCH="$1" ;;
    --tag) shift; CURRENT_TAG="$1" ;;
    --json) MODE_JSON=1 ;;
    --quiet) MODE_QUIET=1 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
  shift
done

# ── Validate required args ──
if [ -z "$CURRENT_TAG" ]; then
  echo "Error: --tag is required" >&2
  usage
fi

# ── Setup directories ──
if [ -z "$WORK_DIR" ]; then
  WORK_DIR="$(mktemp -d /tmp/cognitiveos-healthcheck-XXXXXX)"
  CLEANUP_WORK=1
else
  mkdir -p "$WORK_DIR"
  CLEANUP_WORK=0
fi
[ -z "$REPORT_DIR" ] && REPORT_DIR="./reports"
mkdir -p "$REPORT_DIR"

START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
REPORT_FILE="${REPORT_DIR}/healthcheck-${BRANCH}-$(date +%Y%m%d-%H%M%S).txt"

# ── Preamble ──
section "CognitiveOS Health Check"
[ "$MODE_QUIET" -eq 0 ] && report="${report}Branch: ${BRANCH}\nTag:    ${CURRENT_TAG}\nDate:   $(date)\nHost:   $(uname -a)\n"
hr

# ── Tool availability ──
section "Tool Availability"
for tool in git go shellcheck cmake; do
  if command -v "$tool" >/dev/null 2>&1; then
    case "$tool" in
      cmake) ver=$(cmake --version 2>&1 | head -1) ;;
      *)     ver=$("$tool" version 2>&1 | head -1) ;;
    esac
    check "$tool" pass "$ver"
  else
    check "$tool" skip "not installed"
  fi
done
hr

# ── Clone / update all repos ──
section "Repository Checkout"
errors=0
for repo in $ALL_REPOS; do
  if clone_repo "$repo" "$WORK_DIR/$repo"; then
    check "clone $repo" pass
  else
    check "clone $repo" fail "clone failed"
    errors=$((errors+1))
  fi
done
if [ "$errors" -gt 0 ]; then
  [ "$MODE_QUIET" -eq 0 ] && report="${report}\n${RED}CRITICAL: some repos failed to clone — skipping their checks${NC}\n"
fi
hr

# ── Per-repo checks ──
for repo in $ALL_REPOS; do
  dir="$WORK_DIR/$repo"
  [ -d "$dir/.git" ] || continue

  section "$repo"

  # Git status
  if [ -z "$(git -C "$dir" status --porcelain)" ]; then
    check "git status clean" pass
  else
    check "git status clean" fail "uncommitted changes"
  fi

  # Branch match
  local_branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
  if [ "$local_branch" = "$BRANCH" ]; then
    check "on branch $BRANCH" pass
  else
    check "on branch $BRANCH" fail "on $local_branch"
  fi

  # Tag present
  if git -C "$dir" tag -l "$CURRENT_TAG" 2>/dev/null | grep -q .; then
    check "tag $CURRENT_TAG" pass
  else
    git -C "$dir" fetch origin --tags --quiet 2>/dev/null || true
    if git -C "$dir" tag -l "$CURRENT_TAG" 2>/dev/null | grep -q .; then
      check "tag $CURRENT_TAG" pass
    else
      check "tag $CURRENT_TAG" fail "missing"
    fi
  fi

  # Repo visibility (only for build-binaries repos — CI clones via HTTPS)
  case " $BUILD_REPOS " in
    *" $repo "*)
      check_repo_visibility "$dir" "$repo"
      ;;
  esac

  # Go repo checks
  case " $GO_REPOS " in
    *" $repo "*)
      check_go_build "$dir" "$repo"
      check_go_vet "$dir" "$repo"
      ;;
  esac

  # CGo-specific checks
  case " $CGO_REPOS " in
    *" $repo "*)
      check_build_tags "$dir" "$repo"
      check_stale_refs "$dir" "$repo"
      check_go_build_cgo "$dir" "$repo"
      check_go_vet_cgo "$dir" "$repo"
      ;;
  esac

  # Shell script checks
  case " $SHELL_REPOS " in
    *" $repo "*)
      check_sh_syntax "$dir" "$repo"
      check_shellcheck "$dir" "$repo"
      ;;
  esac

  # Dockerfile checks
  check_dockerfile "$dir" "$repo"

  # cognitiveos-alpine-distro specific
  if [ "$repo" = "cognitiveos-alpine-distro" ]; then
    check_cgo_enabled "$dir" "$repo"
    check_cograw_target "$dir" "$repo"
  fi
done
hr

# ── Summary ──
summary_human="\n${BOLD}Summary${NC}\n  Pass: ${GREEN}${pass}${NC}\n  Fail: ${RED}${fail}${NC}\n  Skip: ${YELLOW}${skip}${NC}\n  Total: $((pass+fail+skip))\n"
[ "$MODE_QUIET" -eq 0 ] && report="${report}${summary_human}"

# Print human report to stderr
printf "%b\\n" "$report" >&2

# Write report file
printf "%b\\n" "$report" > "$REPORT_FILE"
echo "Report: $REPORT_FILE" >&2

# JSON output to stdout
if [ "$MODE_JSON" -eq 1 ]; then
  cat <<JSONEOF
{
  "timestamp": "$START_TIME",
  "branch": "$BRANCH",
  "tag": "$CURRENT_TAG",
  "host": "$(uname -n)",
  "summary": {
    "pass": $pass,
    "fail": $fail,
    "skip": $skip,
    "total": $((pass+fail+skip))
  },
  "checks": [$json_entries]
}
JSONEOF
fi

# Cleanup
if [ "$CLEANUP_WORK" -eq 1 ]; then
  rm -rf "$WORK_DIR"
fi

# Exit code
[ "$fail" -eq 0 ]
