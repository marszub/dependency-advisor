# Harness Follow-up Checklist

**Source:** `docs/tmp/harness_design.md` §8.1 (blocked infrastructure) and §8.3
(future improvements).
**Status:** Open. This file lists only *remaining* work; the harness itself is
implemented and verified.
**Date:** 2026-11-08

Legend: `[ ]` todo · `[x]` done · `[!]` blocked by an earlier item

Recommended order: **1 → 2 → 3 → 4 → 5 → 6**. Items 3–6 need a buildable binary
from item 1.

---

## 1. Bazel workspace

- [ ] Add `MODULE.bazel` with pinned bzlmod dependencies:
  - LLVM/Clang developer packages or an `llvm-project` overlay providing
    `clang-cpp`, `clang-tooling`, `clang-ast`, `llvm-support`
  - GoogleTest, CLI11, nlohmann/json
- [ ] Add `BUILD.bazel` at the root and per-module build files:
  - `src/extractor/BUILD.bazel` — `cc_library` for the extractor plus the
    `cc_binary` entry point
  - `src/graph/BUILD.bazel`, `src/optimizer/BUILD.bazel`, `src/cli/BUILD.bazel`
    when those modules exist
- [ ] Compile with the project flags:
  `-std=c++23 -Wall -Wextra -Werror -Wshadow -Wnon-virtual-dtor -O3`
- [ ] Ensure the extractor target depends on Clang/LLVM and **no other target
  does**.
- [ ] Add the Bazel convenience symlinks to `.gitignore` (already done).

**Acceptance criteria**

```bash
bazel build //...
bazel test //...
./scripts/verify.sh --strict   # exits 0
```

- `bazel test //...` exits 0.
- `verify.sh --strict` no longer reports
  `FAIL: Bazel workspace is required in --strict mode`.
- `bazel query 'deps(//src/graph/...)'` contains no `@llvm`/`@clang` targets
  (run once `src/graph/` exists).

**Notes / risks**

- Fetching and building LLVM via bzlmod is heavy; pin one LLVM major version
  (design doc 6 requires Clang 18/19) and cache it in CI.
- The only current source file is `src/extractor/dependency_extractor.cpp`; its
  target name should be stable so the docs and scripts can reference it.
- Do not add a `glob()`-based target that would silently absorb future modules.

---

## 2. Compilation database for clang-tidy

- [ ] Add a `compilation_database` target or a `refresh_compile_commands` rule
  (e.g. `bazel run //:refresh_compile_commands`).
- [ ] Generate `compile_commands.json` at the repository root (already ignored
  by `.gitignore`).
- [ ] Run `clang-tidy` against the extractor translation unit(s).

**Acceptance criteria**

```bash
bazel run //:refresh_compile_commands
test -f compile_commands.json
clang-tidy -p . src/extractor/dependency_extractor.cpp
```

- `compile_commands.json` exists and contains the extractor file.
- `clang-tidy -p . ...` exits 0, or every remaining diagnostic is either fixed
  or explicitly suppressed with a comment in `.clang-tidy`.
- `./scripts/verify.sh` can be extended with a clang-tidy step that does not
  silently pass when the database is missing.

**Notes / risks**

- The database is generated, so never commit it.
- `clang-tidy -fix` stays behind the `ask` permission; review its diff before
  accepting.

---

## 3. Unit tests (GoogleTest)

- [ ] Create `tests/unit/` with `BUILD.bazel` and a GoogleTest dependency.
- [ ] Add tests for the graph container: node/edge insertion, weights,
  adjacency invariants, empty and disconnected graphs.
- [ ] Add tests for the optimizer: modularity calculation, deterministic seeded
  Louvain/Leiden or HAC, partition invariants, `std::expected` error paths.
- [ ] Add extractor-helper tests that do not launch Clang where possible.
- [ ] Register the tests so `bazel test //...` picks them up.

**Acceptance criteria**

```bash
bazel test //tests/unit/...
./scripts/verify.sh --strict
```

- All unit tests pass under `bazel test //...`.
- A deliberately broken algorithm (e.g. modularity +1) makes at least one test
  fail.
- Every new graph/optimizer feature added after this point ships with a test
  (enforced by the `reviewer` subagent prompt).

**Notes / risks**

- Graph/optimizer tests must not need Clang or a compilation database; keep them
  hermetic (no network, no clock, no absolute paths).
- Prefer asserting invariants over golden partitions for randomized algorithms.

---

## 4. Integration tests (pytest)

- [ ] Create `tests/integration/` with a pytest suite.
- [ ] Add small fixtures under `tests/fixtures/` (one behavior per directory).
- [ ] Exercise the built binary via `subprocess`:
  - `--project-dir` and `--compile-commands` modes
  - `--format=json` schema/keys and exit codes
  - default human-readable report (stable markers, not full golden text)
  - invalid input and error paths
- [ ] Add a pytest invocation to `scripts/verify.sh` (already conditional on the
  directory existing and pytest being importable).

**Acceptance criteria**

```bash
python3 -m pytest tests/integration -q
./scripts/verify.sh --strict
```

- The suite passes locally and in CI.
- A deliberate CLI regression (renamed JSON key, changed exit code) fails at
  least one test.
- Fixtures stay small; no generated build artifacts are committed.

**Notes / risks**

- pytest is currently not installed in this environment; install it in the dev
  container/CI and document the version.
- Bazel can run pytest via `py_test`, but keeping a direct pytest invocation
  makes local debugging simpler; keep both in sync.

---

## 5. Dockerfile

- [ ] Add `Dockerfile` based on Ubuntu 24.04 with:
  - LLVM/Clang development libraries (pin the major version)
  - Bazel (pin the version, ideally via Bazelisk)
  - Python 3 + pytest
- [ ] Run as a non-root user for day-to-day use.
- [ ] Mount the workspace and run the verification suite.

**Acceptance criteria**

```bash
docker build -t dependency-advisor .
docker run --rm -v "$(pwd):/workspace" dependency-advisor ./scripts/verify.sh --strict
```

- The image builds reproducibly.
- `verify.sh --strict` passes inside the container.
- `bazel test //...` passes inside the container.
- Optionally allowlist `docker build *` / `docker run *` in `opencode.json` only
  if the team wants agents to run containers.

**Notes / risks**

- The image will be large (LLVM + Bazel); use a multi-stage build if needed.
- Pin base image digest and tool versions to keep CI and local runs identical.

---

## 6. GitHub Actions CI

- [ ] Add `.github/workflows/ci.yml`.
- [ ] Matrix: Ubuntu 24.04 (primary) and macOS Sonoma; Clang 18/19 and GCC 13.
- [ ] Jobs:
  - **build-test:** `./scripts/verify.sh --strict` with
    `-Wall -Wextra -Werror -pedantic`
  - **static-analysis:** `clang-tidy` over the compilation database
  - **sanitizers:** ASan and UBSan test runs
- [ ] Cache Bazel/LLVM artifacts to keep runtime reasonable.
- [ ] Make boundary, format, and test failures block merges.

**Acceptance criteria**

- A PR that leaks `<clang/...>` outside `src/extractor/` fails CI at
  `scripts/check_boundaries.py`.
- A PR with unformatted C++ fails at the clang-format step.
- A PR with a failing GoogleTest or pytest case fails.
- A green PR shows all matrix jobs passing.
- `./scripts/verify.sh --strict` is the CI entry point (no duplicated command
  lists).

**Notes / risks**

- macOS ships Bash 3.2; `scripts/verify.sh` uses `mapfile` (Bash 4+). Either
  install a modern Bash in the macOS job or port the file collection to a
  `while read` loop (see harness design §8.2 item 8).
- LLVM builds are slow; cache aggressively and consider a prebuilt toolchain.

---

## Definition of done for this checklist

- [ ] `bazel test //...` passes.
- [ ] `./scripts/verify.sh --strict` passes locally, in Docker, and in CI.
- [ ] `clang-tidy -p .` has no unexplained diagnostics.
- [ ] Unit and integration suites cover graph, optimizer, CLI, and output
  formats.
- [ ] CI blocks boundary, format, and test regressions.
- [ ] `docs/tmp/harness_design.md` §8.0 status table is updated (Blocked →
  Implemented) and this file is closed or moved to `docs/design/` as a completed
  record.

## Related records

- Harness design and rationale: `docs/tmp/harness_design.md`
- Design index: `docs/design/README.md`
- Project plan: `docs/design/6_infrastructure_and_project_plan.md`
- Verification entry point: `scripts/verify.sh`
- Boundary check: `scripts/check_boundaries.py`
