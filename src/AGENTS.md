# src/ — Module Rules (loaded automatically when exploring this tree)

Module map and the rules that must hold for every file under `src/`.

| Directory | Responsibility | May include `<clang/...>` / `llvm/...`? |
|-----------|----------------|------------------------------------------|
| `src/extractor/` | Clang LibTooling: AST visiting, matchers, compile-database plumbing. Emits the language-agnostic graph. | **Yes — only here.** |
| `src/graph/` | Pure C++23 graph container: nodes, edges, weights, adjacency. | **No.** |
| `src/optimizer/` | Community detection (Louvain/Leiden, HAC) and modularity/cost optimization. | **No.** |
| `src/cli/` | Argument parsing, terminal rendering, JSON/SARIF serialization. Thin consumer only. | **No.** |
| `src/main.cpp` | Wiring only: parse args, call the engine, hand objects to the CLI layer. | **No.** |

## Non-negotiables

1. **Extractor isolation.** No file outside `src/extractor/` may mention
   `clang::`, `llvm::`, or include a Clang/LLVM header. Run
   `python3 scripts/check_boundaries.py` after touching includes.
2. **Pure graph domain.** `src/graph/` and `src/optimizer/` must be unit-testable
   with GoogleTest without launching Clang: no AST types, no file-system
   parsing, no process execution.
3. **Object-first contracts.** Analysis functions return structured C++ objects
   (graph, metrics, suggestions). Only `src/cli/` renders text or JSON.
4. **Error handling.** Use `std::expected<T, E>` across module boundaries; do not
   throw across them.
5. **C++23.** Build with `-std=c++23`; avoid compiler-specific extensions.
6. **Tests first for algorithms.** Any new edge case in `src/graph/` or
   `src/optimizer/` gets a GoogleTest case under `tests/unit/`.
7. **Verify.** Run `./scripts/verify.sh` (or `bazel test //...` when available)
   and review `git diff` before reporting completion.
