# Claude Code Entry Point

This project keeps a single source of truth for agent guidance: [`AGENTS.md`](AGENTS.md).

Before working, read `AGENTS.md`, then the module rules closest to the code you
touch (`src/AGENTS.md`, `tests/AGENTS.md`). Design rationale lives in
`docs/design/` (index: `docs/design/README.md`) and drafts in `docs/tmp/`.

Key non-negotiables (full detail in `AGENTS.md`):

- Clang/LLVM stays inside `src/extractor/`; `src/graph/` and `src/optimizer/`
  stay pure C++23.
- Core modules return structured objects; only `src/cli/` renders text/JSON.
- Build with C++23 and `std::expected<T, E>` across module boundaries.
- Run `./scripts/verify.sh` and review `git diff` before claiming completion.
- Record design decisions under `docs/`.

Do not duplicate project rules here; update `AGENTS.md` instead.
