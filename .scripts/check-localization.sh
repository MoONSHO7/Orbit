#!/usr/bin/env bash
# Orbit Localization Lint
#
# Run from anywhere. Validates the Orbit.L central localization system:
#   1. Every `L.KEY` reference in the codebase resolves to a defined key.
#   2. Prefix isolation — each domain prefix lives in exactly one file.
#   3. No cross-domain key collisions.
#   4. Reports unused keys as a warning (non-fatal — pre-Phase-4 many keys
#      are pre-populated for future consumer migration).
#
# Exit 0 on success, 1 on any hard failure. Safe to run in CI.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOC_DIR="$REPO_ROOT/Orbit/Localization/Domains"
CODE_ROOT="$REPO_ROOT/Orbit"

if [ ! -d "$LOC_DIR" ]; then
    echo "FAIL: $LOC_DIR not found"
    exit 1
fi

FAIL=0
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== Orbit Localization Lint ==="
echo "Repo: $REPO_ROOT"
echo

# ---------- 1. Extract defined keys from enUS blocks only ----------
# Only the enUS table is the "source of truth". Other locale tables reference
# the same keys and would otherwise count as duplicates.
DEFINED="$TMPDIR/defined.txt"
awk '
    /enUS\s*=\s*\{/ { in_en = 1; depth = 1; next }
    in_en {
        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (c == "{") depth++
            else if (c == "}") { depth--; if (depth == 0) { in_en = 0; next } }
        }
        if (match($0, /^[[:space:]]*([A-Z]{3,4}_[A-Z0-9_]+)[[:space:]]*=/, a)) {
            print a[1]
        }
    }
' "$LOC_DIR"/*.lua | sort -u > "$DEFINED"

DEFINED_COUNT=$(wc -l < "$DEFINED")
echo "Defined keys (enUS source of truth): $DEFINED_COUNT"

# ---------- 2. Extract referenced keys from the codebase ----------
# Any `L.KEY_NAME` where L is preceded by non-identifier (ruling out CL. FL. etc.)
REFERENCED="$TMPDIR/referenced.txt"
grep -rhoE '(^|[^A-Za-z0-9_])L\.[A-Z]{3,4}_[A-Z0-9_]+' \
    --include='*.lua' \
    --exclude-dir=Localization \
    --exclude-dir=Libs \
    "$CODE_ROOT" 2>/dev/null \
    | sed -E 's/^[^L]*L\.//' \
    | sort -u > "$REFERENCED"

REFERENCED_COUNT=$(wc -l < "$REFERENCED")
echo "Referenced keys: $REFERENCED_COUNT"
echo

# ---------- 3. Orphan check (referenced but not defined) ----------
ORPHANS="$TMPDIR/orphans.txt"
comm -23 "$REFERENCED" "$DEFINED" > "$ORPHANS"
ORPHAN_COUNT=$(wc -l < "$ORPHANS")

if [ "$ORPHAN_COUNT" -gt 0 ]; then
    echo "[FAIL] Orphan references ($ORPHAN_COUNT) — used in code, not defined in any domain:"
    sed 's/^/  - L./' "$ORPHANS"
    echo
    FAIL=1
else
    echo "[ OK ] No orphan references."
fi

# ---------- 4. Prefix isolation ----------
echo
echo "=== Prefix isolation ==="
for prefix in CMN CFG PLG PLU CMD MSG TOUR; do
    files=$(grep -lE "^[[:space:]]+${prefix}_[A-Z0-9_]+[[:space:]]*=" "$LOC_DIR"/*.lua 2>/dev/null \
            | xargs -n1 basename 2>/dev/null \
            | tr '\n' ' ' \
            | sed 's/ $//')
    count=$(echo "$files" | tr ' ' '\n' | grep -c . || true)
    if [ "$count" -gt 1 ]; then
        echo "[FAIL] $prefix defined in multiple files: $files"
        FAIL=1
    elif [ "$count" -eq 0 ]; then
        echo "[WARN] $prefix not defined anywhere"
    else
        echo "[ OK ] $prefix: $files"
    fi
done

# ---------- 5. Cross-domain collision check ----------
echo
echo "=== Cross-domain collision check ==="
COLLISIONS="$TMPDIR/collisions.txt"
# Extract all enUS keys with their source file
awk '
    FNR == 1 { file = FILENAME; sub(".*/", "", file); in_en = 0 }
    /enUS\s*=\s*\{/ { in_en = 1; depth = 1; next }
    in_en {
        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (c == "{") depth++
            else if (c == "}") { depth--; if (depth == 0) { in_en = 0; next } }
        }
        if (match($0, /^[[:space:]]*([A-Z]{3,4}_[A-Z0-9_]+)[[:space:]]*=/, a)) {
            print a[1] "\t" file
        }
    }
' "$LOC_DIR"/*.lua | sort | awk -F'\t' '
    { counts[$1]++; files[$1] = files[$1] " " $2 }
    END { for (k in counts) if (counts[k] > 1) print k ":" files[k] }
' > "$COLLISIONS"

COLLISION_COUNT=$(wc -l < "$COLLISIONS")
if [ "$COLLISION_COUNT" -gt 0 ]; then
    echo "[FAIL] Cross-domain collisions ($COLLISION_COUNT):"
    sed 's/^/  - /' "$COLLISIONS"
    FAIL=1
else
    echo "[ OK ] No cross-domain collisions."
fi

# ---------- 6. Unused keys (warning only) ----------
echo
UNUSED="$TMPDIR/unused.txt"
comm -13 "$REFERENCED" "$DEFINED" > "$UNUSED"
UNUSED_COUNT=$(wc -l < "$UNUSED")
if [ "$UNUSED_COUNT" -gt 0 ]; then
    echo "[INFO] Unused keys ($UNUSED_COUNT) — defined but not yet referenced."
    echo "       This is expected pre-Phase-4; keys are pre-populated for migration."
    if [ "${VERBOSE:-0}" = "1" ]; then
        sed 's/^/  - /' "$UNUSED"
    else
        echo "       Run with VERBOSE=1 to list them."
    fi
fi

echo
if [ "$FAIL" -eq 0 ]; then
    echo "[PASS] All hard checks passed."
    exit 0
else
    echo "[FAIL] One or more checks failed."
    exit 1
fi
