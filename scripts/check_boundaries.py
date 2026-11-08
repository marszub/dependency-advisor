#!/usr/bin/env python3
"""Enforce the Clang/LLVM module boundary for Dependency Advisor.

No file outside ``src/extractor/`` may include a Clang or LLVM header, or use a
qualified ``clang::`` / ``llvm::`` name. ``src/graph/`` and ``src/optimizer/``
must stay pure C++23 so they can be unit-tested without launching Clang.

Usage:
    python3 scripts/check_boundaries.py [--root PATH]

Exit codes:
    0  no violations
    1  at least one violation
    2  invalid invocation / unreadable root
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CXX_EXTENSIONS = {
    ".c",
    ".cc",
    ".cpp",
    ".cxx",
    ".c++",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".h++",
    ".ipp",
    ".inl",
}

ALLOWED_PREFIX = ("src", "extractor")

INCLUDE_RE = re.compile(r'^\s*#\s*include\s*[<"](?:clang|llvm)/', re.MULTILINE)
QUALIFIED_RE = re.compile(r"\b(?:clang|llvm)::")
SCAN_ROOTS = ("src", "tests")


def line_number(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def scan_file(path: Path, root: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:  # pragma: no cover - defensive
        return [f"{path}: could not read file: {exc}"]

    rel = path.relative_to(root)
    violations: list[str] = []

    for match in INCLUDE_RE.finditer(text):
        violations.append(
            f"{rel}:{line_number(text, match.start())}: "
            "Clang/LLVM include outside src/extractor/"
        )
    for match in QUALIFIED_RE.finditer(text):
        violations.append(
            f"{rel}:{line_number(text, match.start())}: "
            f"'{match.group(0)}' usage outside src/extractor/"
        )
    return violations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Repository root to scan (default: parent of this script).",
    )
    args = parser.parse_args(argv)

    root: Path = args.root.resolve()
    if not root.is_dir():
        print(f"error: root is not a directory: {root}", file=sys.stderr)
        return 2

    violations: list[str] = []
    scanned = 0
    for name in SCAN_ROOTS:
        base = root / name
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in CXX_EXTENSIONS:
                continue
            rel_parts = path.relative_to(root).parts
            if rel_parts[:2] == ALLOWED_PREFIX:
                continue
            scanned += 1
            violations.extend(scan_file(path, root))

    for violation in violations:
        print(violation)

    if violations:
        print(
            f"\nBoundary check FAILED: {len(violations)} violation(s) "
            f"in {scanned} scanned file(s).",
            file=sys.stderr,
        )
        return 1

    print(
        f"Boundary check passed: {scanned} file(s) scanned; "
        "Clang/LLVM confined to src/extractor/."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
