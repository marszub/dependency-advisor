# tests/ — Testing Rules (loaded automatically when exploring this tree)

| Directory | Framework | Purpose |
|-----------|-----------|---------|
| `tests/unit/` | GoogleTest (Bazel) | Pure C++ tests for `src/graph/`, `src/optimizer/`, and extractor helpers. No Clang process launch. |
| `tests/integration/` | Python `pytest` | End-to-end runs of the built `dependency-advisor` binary against fixtures. |
| `tests/fixtures/` | C++ sample projects | Small, focused codebases with known expected suggestions. |

## Rules

1. Every new graph algorithm, metric, or optimizer feature ships with unit tests
   in the same change. A feature without tests is not complete.
2. Every change to CLI flags, report text, JSON, SARIF, or exit codes ships with
   a pytest integration test that asserts the observable behavior.
3. Fixtures must stay small and minimal; one behavior per fixture directory.
4. Keep unit tests hermetic: no network, no real clock, no absolute paths.
5. Run `./scripts/verify.sh` before marking a task complete; use
   `./scripts/verify.sh --strict` once the Bazel workspace and pytest suite
   exist. It runs the boundary check, formatting check, Bazel tests, and pytest.
6. Tests must be deterministic. If an algorithm is randomized, seed it explicitly
   and assert on invariants, not on a single golden partition.
