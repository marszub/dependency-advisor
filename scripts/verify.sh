#!/usr/bin/env bash
# Repository verification entry point for humans, CI, and AI agents.
#
# Usage:
#   ./scripts/verify.sh            # run available checks, skip missing toolchains
#   ./scripts/verify.sh --strict   # fail when Bazel/pytest are required but absent
#
# The script never stages or commits. Evidence (commands + exit codes) is printed
# so an agent can report verifiable results.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

STRICT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

FAILURES=0
SKIPPED=0

section() {
  printf '\n== %s\n' "$1"
}

record() {
  local name="$1"
  local rc="$2"
  if [ "$rc" -eq 0 ]; then
    printf 'PASS: %s\n' "$name"
  else
    printf 'FAIL: %s (exit %s)\n' "$name" "$rc"
    FAILURES=$((FAILURES + 1))
  fi
}

skip() {
  printf 'SKIP: %s\n' "$1"
  SKIPPED=$((SKIPPED + 1))
}

# ---------------------------------------------------------------- boundaries
section "Module boundary check"
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/check_boundaries.py
  record "module boundary check" "$?"
else
  skip "module boundary check (python3 not found)"
  if [ "$STRICT" -eq 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf 'FAIL: python3 is required in --strict mode\n'
  fi
fi

# ------------------------------------------------------------------ formatting
section "Formatting check (clang-format)"
if command -v clang-format >/dev/null 2>&1 && [ -f .clang-format ]; then
  mapfile -t FILES < <(
    git ls-files -co --exclude-standard -- \
      '*.c' '*.cc' '*.cpp' '*.cxx' '*.c++' \
      '*.h' '*.hh' '*.hpp' '*.hxx' '*.h++' '*.ipp' '*.inl' 2>/dev/null
  )
  PRESENT=()
  for f in "${FILES[@]}"; do
    [ -f "$f" ] && PRESENT+=("$f")
  done
  if [ "${#PRESENT[@]}" -eq 0 ]; then
    skip "formatting check (no C/C++ files)"
  else
    FMT_RC=0
    for f in "${PRESENT[@]}"; do
      echo "  checking $f"
      clang-format --dry-run --Werror "$f" || FMT_RC=1
    done
    record "clang-format (${#PRESENT[@]} file(s))" "$FMT_RC"
  fi
else
  skip "formatting check (clang-format or .clang-format missing)"
fi

# ------------------------------------------------------------------------ build
section "Build and unit tests (Bazel)"
if command -v bazel >/dev/null 2>&1 && { [ -f MODULE.bazel ] || [ -f WORKSPACE ] || [ -f BUILD.bazel ]; }; then
  bazel test //...
  record "bazel test //..." "$?"
else
  skip "bazel test //... (Bazel or Bazel workspace not configured yet)"
  if [ "$STRICT" -eq 1 ]; then
    FAILURES=$((FAILURES + 1))
    printf 'FAIL: Bazel workspace is required in --strict mode\n'
  fi
fi

# ------------------------------------------------------------------ integration
section "Integration tests (pytest)"
if [ -d tests/integration ] && python3 -c 'import pytest' >/dev/null 2>&1; then
  python3 -m pytest tests/integration -q
  record "pytest tests/integration" "$?"
else
  skip "pytest tests/integration (no suite or pytest unavailable)"
  if [ "$STRICT" -eq 1 ] && [ -d tests/integration ]; then
    FAILURES=$((FAILURES + 1))
    printf 'FAIL: pytest is required in --strict mode\n'
  fi
fi

# ------------------------------------------------------------------- hygiene
section "Patch hygiene"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git diff --check
  record "git diff --check (whitespace errors)" "$?"
  printf '\nChanged files:\n'
  git status --short
else
  skip "git diff --check (not a git work tree)"
fi

printf '\n== Summary\n'
printf 'Failures: %d, skipped: %d\n' "$FAILURES" "$SKIPPED"
if [ "$FAILURES" -ne 0 ]; then
  printf 'Verification FAILED\n'
  exit 1
fi
printf 'Verification PASSED\n'
