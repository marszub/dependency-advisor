# GitHub Copilot Instructions

The authoritative project guidance is [`AGENTS.md`](../AGENTS.md). Read it and
the nearest module file (`src/AGENTS.md`, `tests/AGENTS.md`) before suggesting
changes.

Summary of the non-negotiables:

- Clang/LLVM stays inside `src/extractor/`.
- `src/graph/` and `src/optimizer/` stay pure C++23 and Clang-free.
- Core modules return structured objects; only `src/cli/` renders text/JSON.
- C++23 with `std::expected<T, E>` at module boundaries.
- Verify with `./scripts/verify.sh`; record design decisions in `docs/`.

Keep this file a pointer; update `AGENTS.md` for rule changes.
