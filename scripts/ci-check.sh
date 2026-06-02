#!/usr/bin/env bash
# CentrexOS CI pre-merge check — run locally before pushing
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo -e "\033[1;32m  ✓\033[0m $*"; ((PASS++)); }
fail() { echo -e "\033[1;31m  ✗\033[0m $*"; ((FAIL++)); }
head() { echo -e "\n\033[1;36m━━ $* ━━\033[0m"; }

# ---------------------------------------------------------------------------
head "Rust: format check"
for manifest in core/Cargo.toml cxpkg/Cargo.toml installer/Cargo.toml; do
    full="$ROOT_DIR/$manifest"
    [[ -f "$full" ]] || continue
    if cargo fmt --manifest-path "$full" -- --check 2>/dev/null; then
        pass "$(dirname "$manifest") formatting OK"
    else
        fail "$(dirname "$manifest") has formatting issues (run 'cargo fmt')"
    fi
done

# ---------------------------------------------------------------------------
head "Rust: clippy"
for manifest in core/Cargo.toml cxpkg/Cargo.toml installer/Cargo.toml; do
    full="$ROOT_DIR/$manifest"
    [[ -f "$full" ]] || continue
    if cargo clippy --manifest-path "$full" -- -D warnings 2>/dev/null; then
        pass "$(dirname "$manifest") clippy clean"
    else
        fail "$(dirname "$manifest") has clippy warnings"
    fi
done

# ---------------------------------------------------------------------------
head "Rust: tests"
for manifest in core/Cargo.toml cxpkg/Cargo.toml; do
    full="$ROOT_DIR/$manifest"
    [[ -f "$full" ]] || continue
    if cargo test --manifest-path "$full" --quiet 2>/dev/null; then
        pass "$(dirname "$manifest") tests passed"
    else
        fail "$(dirname "$manifest") tests FAILED"
    fi
done

# ---------------------------------------------------------------------------
head "Metadata: JSON validity"
while IFS= read -r -d '' f; do
    if jq . "$f" > /dev/null 2>&1; then
        pass "JSON valid: ${f#$ROOT_DIR/}"
    else
        fail "JSON invalid: ${f#$ROOT_DIR/}"
    fi
done < <(find "$ROOT_DIR/metadata" -name "*.json" -print0)

# ---------------------------------------------------------------------------
head "Shell scripts: shellcheck"
if command -v shellcheck &>/dev/null; then
    while IFS= read -r -d '' f; do
        if shellcheck "$f" 2>/dev/null; then
            pass "shellcheck: ${f#$ROOT_DIR/}"
        else
            fail "shellcheck: ${f#$ROOT_DIR/}"
        fi
    done < <(find "$ROOT_DIR" -name "*.sh" -not -path "*/.git/*" -print0)
else
    echo "  (shellcheck not installed — skipping)"
fi

# ---------------------------------------------------------------------------
head "Summary"
TOTAL=$((PASS + FAIL))
echo "  Passed: $PASS / $TOTAL"
[[ $FAIL -eq 0 ]] || echo -e "  Failed: \033[1;31m$FAIL\033[0m"
[[ $FAIL -eq 0 ]]
