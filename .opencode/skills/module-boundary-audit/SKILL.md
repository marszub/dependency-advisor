---
name: Module Boundary Audit
description: Verify that Clang/LLVM stays inside src/extractor and that graph/optimizer stay pure C++23
---

# Module Boundary Audit

Use this skill before committing changes that touch includes, CMake/Bazel target
dependencies, or anything under `src/graph/`, `src/optimizer/`, or
`src/extractor/`.

## Procedure

1. Run the mechanical check from the repository root:

   ```bash
   python3 scripts/check_boundaries.py
   ```

   It scans every C/C++ file under `src/` and `tests/`, skipping
   `src/extractor/`, and fails on Clang/LLVM includes or `clang::` / `llvm::`
   names. Exit code 1 means a violation.

2. Inspect the pure modules for non-mechanical coupling that a regex cannot see:

   ```bash
   grep -rnE 'ASTContext|SourceManager|CompilerInstance|tooling::' src/graph src/optimizer 2>/dev/null
   grep -rnE 'std::system|popen|fork|exec' src/graph src/optimizer 2>/dev/null
   grep -rnE 'std::cout|std::cerr|printf|nlohmann|CLI11' src/graph src/optimizer 2>/dev/null
   ```

   Any hit is a boundary smell: graph/optimizer must not parse code, run
   processes, or render output.

3. Confirm the presentation boundary: only `src/cli/` should format text or
   serialize JSON/SARIF. Core modules return structured objects.

4. Report violations as `path:line: what leaked`. Propose the minimal fix:
   move the type behind an extractor-owned DTO, or move rendering into
   `src/cli/`.

## Done criteria

- `python3 scripts/check_boundaries.py` exits 0.
- No grep hit in `src/graph/` or `src/optimizer/` is left unexplained.
- If a boundary had to move, the decision is recorded in `docs/design/` via the
  `design-documentation` skill.
