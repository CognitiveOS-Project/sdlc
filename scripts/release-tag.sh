#!/bin/sh
# release-tag.sh — Coordinate annotated SemVer tags across all CognitiveOS repos
#
# Usage:
#   ./release-tag.sh v1.0.0-alpha "System foundations complete"
#   ./release-tag.sh --dry-run v1.0.0-alpha "System foundations complete"
#   ./release-tag.sh --list
#
# Env:
#   COGNITIVEOS_RELEASE_DIR   Clone cache directory (default: ~/.cache/cognitiveos/releases)
#
# Requires: gh (SSH-configured), network access to github.com

set -e

BASE_DIR="${COGNITIVEOS_RELEASE_DIR:-$HOME/.cache/cognitiveos/releases}"
ORG="CognitiveOS-Project"
REPOS="coginit cognitiveos product-specs sdlc cpm core-mcp-bridges inference cognitiveosd cli registry-server cgp-template cognitiveos-alpine-distro cognitive-os.org .github"

# Map remote repo names to local checkout directories.
# .github collides with /.github in the workspace root (see AGENTS.md).
repo_dir() {
    case "$1" in
        .github) echo "org-repo" ;;
        *)       echo "$1" ;;
    esac
}

list_tags() {
    echo "=== Current tags per repo ==="
    for repo in $REPOS; do
        target="$BASE_DIR/$(repo_dir "$repo")"
        if [ -d "$target/.git" ]; then
            latest=$(cd "$target" && git tag -l 'v*' 2>/dev/null | sort -V | tail -1)
            echo "  $repo  ${latest:-no tags}"
        else
            echo "  $repo  (not cloned)"
        fi
    done
}

if [ "${1:-}" = "--list" ]; then
    list_tags
    exit 0
fi

# --- argument parsing ---
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    shift
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 [--dry-run] <version> <message>"
    echo "       $0 --list"
    echo ""
    echo "Examples:"
    echo "  $0 v1.0.0-alpha \"System foundations complete\""
    echo "  $0 --dry-run v1.0.0-alpha \"System foundations complete\""
    echo "  $0 --list"
    exit 1
fi

VERSION="$1"
MSG="$2"

if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+'; then
    echo "Error: version must match semver format (e.g. v1.0.0-alpha)"
    exit 1
fi

# --- header ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Coordinated Release Tag"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Version:  $VERSION"
echo "  Message:  $MSG"
echo "  Cache:    $BASE_DIR"
[ "$DRY_RUN" = true ] && echo "  Mode:     DRY RUN (no changes)"
echo ""

# --- ensure base dir ---
if [ "$DRY_RUN" = false ] && ! mkdir -p "$BASE_DIR" 2>/dev/null; then
    echo "Error: cannot create base directory $BASE_DIR"
    echo "Set COGNITIVEOS_RELEASE_DIR to a writable path"
    exit 1
fi

FAILED=0
SUCCEEDED=0
RESULTS_FILE=$(mktemp)

for repo in $REPOS; do
    target="$BASE_DIR/$(repo_dir "$repo")"
    repo_label=$(printf "%-18s" "$repo")

    if [ "$DRY_RUN" = true ]; then
        echo "  $repo_label~ tag $VERSION (dry-run)"
        echo "$repo  ~ tag $VERSION" >> "$RESULTS_FILE"
        SUCCEEDED=$((SUCCEEDED + 1))
        continue
    fi

    # clone if not present
    if [ ! -d "$target/.git" ]; then
        if ! gh repo clone "${ORG}/${repo}" "$target" 2>/dev/null; then
            echo "  $repo_label✗ clone failed"
            echo "$repo  ✗ clone failed" >> "$RESULTS_FILE"
            FAILED=$((FAILED + 1))
            continue
        fi
    fi

    # fetch, tag, push — subshell for isolation
    if (cd "$target" && \
        git fetch --tags --force origin 2>/dev/null && \
        git tag -a "$VERSION" -m "$MSG" 2>/dev/null && \
        git push origin "$VERSION" 2>/dev/null); then
        echo "  $repo_label✓ $VERSION"
        echo "$repo  ✓ $VERSION" >> "$RESULTS_FILE"
        SUCCEEDED=$((SUCCEEDED + 1))
    else
        # tag already exists → skip, not error
        if (cd "$target" && git tag -l "$VERSION" 2>/dev/null | grep -qFx "$VERSION"); then
            echo "  $repo_label- already exists"
            echo "$repo  - already exists" >> "$RESULTS_FILE"
            SUCCEEDED=$((SUCCEEDED + 1))
        else
            echo "  $repo_label✗ failed"
            echo "$repo  ✗ failed" >> "$RESULTS_FILE"
            FAILED=$((FAILED + 1))
        fi
    fi
done

# --- summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " RESULTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sort "$RESULTS_FILE"
rm -f "$RESULTS_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  $SUCCEEDED succeeded, $FAILED failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$FAILED" -gt 0 ] && exit 1 || exit 0
