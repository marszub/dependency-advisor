# AGENTS.md: Developer & AI Agent Guide for Dependency Advisor

> **Notice for AI Agents (OpenCode, Claude Code, Cursor, Copilot, etc.):** 
> This file is your primary project entry point and operational manual. Read this document thoroughly before performing any task in this repository.

---

## 1. Project Overview & Core Mission
**Dependency Advisor** is a modern C++23 static analysis tool that analyzes C++ codebases using Clang LibTooling, builds dependency and call graphs, and applies graph community detection algorithms (e.g., Louvain/Leiden) and cost minimization to suggest structural refactorings (such as moving methods between classes, splitting monolithic classes, and improving overall architectural cohesion).

---

## 2. Architecture & Module Boundaries (The "Non-Negotiable" Rules)

To maintain a clean, testable, and robust codebase, code must strictly adhere to these module boundaries:
   - **Clang AST Extraction (`src/extractor/`):** Interacts with Clang LibTooling (`clang::CallExpr`, `clang::MemberExpr`, compilation databases). **Clang extraction code *never* leaks outside `src/extractor/`.** No other module may include `<clang/...>` headers or depend directly on LLVM/Clang libraries. This is enforced mechanically by `python3 scripts/check_boundaries.py`.
   - **Pure Graph Domain (`src/graph/` & `src/optimizer/`):** Pure C++23 modules operating entirely on language-agnostic graph representations (`std::unordered_map`, adjacency lists, node weights, edge weights). **Must be fully unit-testable without launching Clang or requiring LLVM headers.**
   - **Object-First / API-First Contracts:** Core analysis engines do not output raw terminal strings or JSON directly. They return structured C++ objects representing graphs, cohesion metrics, and refactoring suggestions.
   - **Presentation / Consumer Layers (`src/cli/`):** Handles CLI argument parsing (via CLI11) and terminal UI rendering or machine-readable serialization (JSON/SARIF).

---

## 3. Coding Standards & C++23 Guidelines

- **Language Standard:** ISO C++23 (`-std=c++23`).
- **Style Guide:** Google C++ Style Guide adapted for modern C++23.
- **Error Handling:** Prefer `std::expected<T, E>` over exceptions across module boundaries. Use exceptions sparingly or strictly within local subsystem scopes.
- **Linters & Formatters:**
  - Automated formatting via `clang-format`.
  - Static linting via `clang-tidy` (checking for modern C++ idioms, safety, and performance).
  - **Review Rule:** AI agents and developers may run tools like `clang-format` or `clang-tidy -fix`, but **all modifications must be explicitly reviewed (e.g. via `git diff`) before staging and committing**. No silent unreviewed modifications.
- **Compiler Flags:** `-std=c++23 -Wall -Wextra -Werror -Wshadow -Wnon-virtual-dtor -O3`.

---

## 4. Build System & Workflow

- **Build System:** **Bazel** (`MODULE.bazel` / `BUILD.bazel`).
- **Verification entry point (preferred for agents):**
  ```bash
  ./scripts/verify.sh          # runs every available check, skips missing toolchains
  ./scripts/verify.sh --strict # fails when Bazel or pytest are unavailable
  ```
- **Build & Test Command (once the Bazel workspace exists):**
  ```bash
  bazel test //...
  ```
- **Artifact Hygiene:** Bazel local build outputs (`bazel-bin`, `bazel-out`, convenience symlinks) are strictly ignored via `.gitignore`.
- **Containerized Environment:**
  ```bash
  docker build -t dependency-advisor .
  docker run --rm -v $(pwd):/workspace dependency-advisor bazel test //...
  ```

---

## 5. Testing Requirements

- **Unit Tests (`tests/unit/`):**
  - Framework: **GoogleTest** integrated via Bazel.
  - Requirement: Every new graph algorithm, metric calculation, or optimizer feature must include comprehensive unit tests.
- **Integration Tests (`tests/integration/`):**
  - Framework: **Python (`pytest`)**.
  - Requirement: End-to-end changes affecting CLI output behavior, JSON formats, or analysis accuracy must be verified via Python integration tests against fixtures in `tests/fixtures/`.

---

## 6. AI Agent Best Practices & Operational Protocol

When working as an AI coding agent on this repository (whether via **OpenCode**, **Claude Code**, **Cursor**, or other harnesses), follow these protocols:

1. **Leverage Harness Native Tools & Capabilities:**
   - **OpenCode Sessions & Subagents:** Use OpenCode subagents (`explore`, `general`) to run parallel research or multi-step analysis tasks without cluttering the main session context.
   - **Context Exploration:** Reference `docs/design/` for deep architectural rationale (e.g., math models in `4_math_and_algorithms.md`, Clang matchers in `3_clang_integration.md`).
2. **Verify Before Committing:** Always run `./scripts/verify.sh` (or at minimum `bazel test //...` when the Bazel workspace exists) and inspect `git diff` prior to considering any task complete. Never claim success without command output.
3. **Respect Module Boundaries:** Never introduce Clang/LLVM dependencies into `src/graph/` or `src/optimizer/`. Keep graph algorithms purely language-agnostic and unit-testable. Run `python3 scripts/check_boundaries.py` after touching includes.
4. **Object-First Design:** Ensure core logic produces structured C++ objects, letting CLI/JSON formatters consume them separately.
5. **Living Documentation & Design Output:** 
   - The `docs/` directory (especially `docs/design/`) serves as the permanent text output repository for agent decisions, architectural specs, and technical notes.
   - Whenever a significant design decision is made, an algorithm is designed, or an architectural pattern is adopted or modified, agents must create new design files or update existing ones in `docs/` to capture the rationale, trade-offs, and specifications for future developers and AI agents.
   - Use the `design-documentation` skill and the `/design` command; keep `docs/design/README.md` in sync.
6. **Harness Shortcuts:** In OpenCode, prefer `/verify`, `/format`, `/design`, `/review`, and `/boundary-audit`. Use the `reviewer`, `design-documenter`, and `clang-extractor` subagents for read-only review, documentation, and extractor-only work. Configuration and rationale live in `opencode.json` and `docs/tmp/harness_design.md`.
