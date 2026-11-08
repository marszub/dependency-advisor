# 6. Comprehensive Project Infrastructure and Architecture Specification

This document synthesizes the design requirements, build systems, tooling, modern C++23 features, continuous integration, UX/UI, and competitive analysis for the **Dependency Advisor** project.

---

## 1. Build System: Bazel

### Selection & Rationale
We select **Bazel** as the primary build system for Dependency Advisor.
* **Hermetic & Reproducible:** Bazel sandboxes builds, ensuring exact version pinning for external dependencies (such as LLVM/Clang libraries, GoogleTest, CLI11, nlohmann/json).
* **Precise Dependency Graph:** Bazel natively handles C++ module/library targets and massive codebases without fragile globbing or include-path drift.
* **External Repositories (`bzlmod`):** Bazel's modern module system (`MODULE.bazel`) makes fetching and compiling LLVM/Clang developer packages and testing frameworks robust and cross-platform.

### Build Artifacts & Repository Hygiene
While Bazel and other build tools generate artifacts locally in the workspace (via convenience symlinks like `bazel-bin`, `bazel-out`, etc.), we strictly prevent them from leaking into version control by ensuring all local build outputs and symlinks are covered by `.gitignore`. This gives developers convenient local access to build products and compile databases without risking repository pollution.

---

## 2. Compiler: Clang (LLVM Toolchain) & C++23 Standard

### Compiler Selection
* **Primary Compiler:** **Clang** (`clang++` / LLVM 18+ or 19+), ensuring native compatibility with Clang LibTooling (`libclang-cpp`, `clang-ast`, `clang-tooling`).
* **Secondary Supported Compiler:** GCC (`g++` 13+) for production release builds where Clang LibTooling is not directly compiling code.
* **Language Standard:** ISO C++23 configured across the build system.

---

## 3. AI, Model-Agnostic Instructions, and Harness Integration

* **AI Agent & Harness:** Designed to be run and maintained via OpenCode or standard model-agnostic coding harnesses (Claude Code, Cursor, OpenCode subagents).
* **Context Preservation:** All design decisions are captured in `docs/design/` and this master infrastructure document.
* **Prompting / Agent Guidelines:**
  - **A. Architecture & Module Boundaries (The "Non-Negotiable" Rules):**
    - Strict separation of concerns: Clang AST extraction code *never* leaks outside `src/extractor/`.
    - Object-First / API-First Contracts: Core algorithmic and analysis modules must return structured C++ objects rather than raw CLI text or JSON directly.
    - Pure Graph Domain: `src/graph/` and `src/optimizer/` must be pure C++23, operating entirely on language-agnostic graph representations so they can be unit-tested without launching Clang.
  - **B. Coding Standards & C++23 Guidelines:**
    - Language Standard: ISO C++23.
    - Linters & Formatters: Agents are encouraged to actively run tools like `clang-format` or `clang-tidy -fix` to keep code clean, but **all modifications must be explicitly reviewed (e.g. via `git diff`) before staging and committing**. No silent unreviewed modifications.
    - Error Handling: Prefer `std::expected<T, E>` over exceptions across module boundaries.
  - **C. Testing Requirements:**
    - Unit Tests (`tests/unit/`): Every new graph algorithm or optimizer feature must include unit tests written in GoogleTest.
    - Integration Tests (`tests/integration/`): End-to-end changes affecting CLI or output behavior must be verified via Python (`pytest`) integration tests against fixtures in `tests/fixtures/`.
  - **D. Workflow & Build Verification:**
    - Build and test using Bazel (`bazel test //...`) once the Bazel workspace exists; until then, run the repository entry point `./scripts/verify.sh` (`--strict` when a full toolchain is available). Never claim completion without command output.
  - **E. Harness Integration & Advanced Configuration (`opencode.json`):**
    - Layered instructions: root `AGENTS.md`, module-scoped `src/AGENTS.md` and `tests/AGENTS.md`, and the `docs/design/README.md` index are loaded automatically. Thin pointers (`CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) keep other harnesses on the same source of truth.
    - Project agents: `cpp-expert` (default implementation agent), `reviewer` (read-only subagent), `design-documenter` (docs-only subagent), `clang-extractor` (extractor-only subagent). See `docs/tmp/harness_design.md`.
    - Custom commands: `/verify`, `/format`, `/design`, `/review`, `/boundary-audit`. Skills: `design-documentation`, `module-boundary-audit`.
    - Permissions are deny-by-default for risky shell operations (`git push`, `git reset --hard`, `git clean`, `rm -rf`, `sudo`), ask for mutations, and allow read-only Git plus Bazel/clang-format verification commands.
    - Mechanical enforcement: `scripts/check_boundaries.py` (Clang/LLVM confinement), `.clang-format` + `.clang-tidy`, and `scripts/verify.sh` (boundary, format, Bazel, pytest, whitespace). `formatter: true` applies `clang-format` after agent edits; the watcher ignores Bazel outputs.
    - **Living Documentation:** Maintain `docs/` as the permanent text output repository for architectural decisions, algorithm designs, and technical rationale. The full improvement analysis, tool matrix, exclusions, and verification evidence live in `docs/tmp/harness_design.md`.

---

## 4. File Structure & Module Division in Code

### Repository File Structure
```text
dependency-advisor/
├── MODULE.bazel                 # Bazel external dependencies (LLVM, GTest, CLI11)
├── BUILD.bazel                  # Root build file
├── .github/
│   └── workflows/
│       └── ci.yml               # GitHub Actions CI pipeline
├── docs/
│   └── design/                  # Design documents (1 through 5)
├── src/
│   ├── extractor/               # Clang LibTooling implementation & headers
│   ├── graph/                   # Graph data structures & adjacency models
│   ├── optimizer/               # Louvain / HAC / Cost minimization algorithms
│   ├── cli/                     # CLI argument parsing & output formatters
│   └── main.cpp                 # Application entry point
├── tests/
│   ├── unit/                    # Unit tests for graph & optimizer
│   ├── integration/             # End-to-end refactoring analysis tests
│   └── fixtures/                # Sample C++ codebases for testing
└── Dockerfile                   # Containerized execution environment
```

Harness-specific files (`opencode.json`, `.opencode/`, `scripts/`, `AGENTS.md`,
and the cross-harness pointer files) are specified in
`docs/tmp/harness_design.md`; the tree above remains the product layout.

### Module Division & Boundaries
1. **`extractor` Module:** Interacts with Clang LibTooling (`clang::CallExpr`, `clang::MemberExpr`). Emits a language-agnostic intermediate graph interchange format in memory. **No other module may include `<clang/...>` headers.**
2. **`graph` Module:** Pure C++23 graph container (`std::unordered_map`, adjacency lists, node weights, edge weights). Fully testable without Clang.
3. **`optimizer` Module:** Implements community detection (Louvain/Leiden) and modularity maximization to group functions into optimal classes.
4. **`cli` Module:** Handles argument parsing and terminal UI rendering.

---

## 5. Testing Framework & Strategy

* **Unit Testing Framework:** **GoogleTest** (`googletest`) integrated via Bazel `MODULE.bazel` for testing low-level graph algorithms, cohesion score calculations, and partitioning correctness against synthetic test graphs (`tests/unit/`).
* **Integration & E2E Testing:** **Python (`pytest`)** for running end-to-end integration tests (`tests/integration/`). Python scripts orchestrate temporary fixture codebases (`tests/fixtures/`), execute the compiled `dependency-advisor` binary via subprocess, and assert correctness on output reports, JSON structures, and exit codes.

---

## 6. GitHub Actions / CI Jobs

### CI Pipeline Design (`.github/workflows/ci.yml`)
1. **Matrix Build:**
   - Operating Systems: Ubuntu 24.04 (Primary), macOS Sonoma.
   - Compilers: Clang 18/19 and GCC 13.
2. **Jobs:**
   - **Build & Test:** Runs `bazel test //...` with strict compiler warnings (`-Wall -Wextra -Werror -pedantic`).
   - **Static Analysis / Linter:** Runs `clang-tidy` to enforce modern C++23 coding standards.
   - **Sanitizers:** AddressSanitizer (ASan) and UndefinedBehaviorSanitizer (UBSan) verification job.

---

## 7. Coding Standards and Enforcement

* **Standard:** ISO C++23.
* **Style Guide:** Google C++ Style Guide adapted for modern C++23.
* **Enforcement Tools:**
  - **`clang-format`:** Automated formatting enforced via pre-commit hooks and CI check (`bazel run //:format-check`).
  - **`clang-tidy`:** Static linting checking for modern C++ idioms, safety, and performance.
  - **Compiler Flags:** `-std=c++23 -Wall -Wextra -Werror -Wshadow -Wnon-virtual-dtor -O3`.

---

## 8. System-Agnostic Utilities & Docker

* **Containerization (`Dockerfile`):**
  - Uses an official Ubuntu 24.04 image with pre-installed LLVM/Clang development libraries, Bazel, and build essentials.
  - Allows developers on any host OS (Windows/Linux/macOS) to build and run Dependency Advisor identically inside Docker:
    ```bash
    docker build -t dependency-advisor .
    docker run --rm -v $(pwd):/workspace dependency-advisor bazel test //...
    ```

---

## 9. UX/UI & Architecture Design: Object-First / API-First Approach

### Core Philosophy: Object-First Architecture
In alignment with modern software engineering paradigms adopted by industry leaders (such as Nokia and Arista), Dependency Advisor is built around an **Object-First / API-First** architecture. 
* The core analysis engine does not output raw human-readable terminal strings or JSON text directly. Instead, it produces structured C++ data objects representing the graph, cohesion metrics, and refactoring suggestions.
* The **CLI** (and any future IDE extensions, Web UI, or LSP servers) are treated merely as thin presentation/consumer layers that serialize or render these core objects into various formats (human-friendly text reports or machine-readable JSON).

### Program Execution Syntax
```bash
dependency-advisor [options] --project-dir=<path> -- [compiler flags...]
```
Or utilizing a compilation database:
```bash
dependency-advisor --compile-commands=build/compile_commands.json --format=json
```

### Output Formats (Consumer Layers)

#### 1. Machine-Readable Format (`--format=json` / SARIF)
Designed for CI/CD integration, automated refactoring pipelines, and IDE extensions (VS Code, CLion, Neovim plugins):
```json
{
  "version": "1.0.0",
  "metrics": {
    "files_analyzed": 42,
    "functions_analyzed": 318,
    "cohesion_score": 0.61
  },
  "suggestions": [
    {
      "confidence": "high",
      "action": "move_method",
      "function": "RenderEngine::calculate_lighting",
      "source_class": "RenderEngine",
      "target_class": "ShaderPipeline",
      "rationale": "High data access and call frequency with target class."
    }
  ]
}
```

#### 2. Human-Friendly Interactive Text Report (Default CLI Presentation)
A terminal-rendered view of the underlying objects for quick interactive investigation by developers:

```text
======================================================================
                 DEPENDENCY ADVISOR REFACTORING REPORT
======================================================================
Analyzed: 42 files, 318 functions, 1,420 dependency edges.
Overall Cohesion Score: 0.61 (Poor — High cross-class coupling detected)

--- SUGGESTED REFACTORING ACTIONS ---

1. [HIGH CONFIDENCE] Move Method: `RenderEngine::calculate_lighting`
   - Current Owner: Class `RenderEngine` (in `src/renderer.cpp`)
   - Recommended Owner: Class `ShaderPipeline` (in `src/shader.cpp`)
   - Rationale: 84% of data accesses and 92% of calls are to `ShaderPipeline` internals. Moving this function reduces coupling by 34%.

2. [MEDIUM CONFIDENCE] Split Monolithic Class: `AssetManager`
   - Current Owner: Class `AssetManager` (`src/asset.cpp`)
   - Recommendation: Extract texture loading methods into new class `TextureCache`.
   - Rationale: Natural community detection boundary found (Modularity delta: +0.22).

======================================================================
```

---

## 10. Existing Tools, Projects, and Ecosystem Inspiration

1. **Clang LibTooling & LibASTMatchers:** The industry standard for precise C++ static analysis.
2. **Lizard / SonarQube / CppDepend:** Commercial/legacy static analyzers. Unlike SonarQube (which measures broad metrics like cyclomatic complexity and lines of code), Dependency Advisor uses graph-theoretic modularity optimization to suggest *structural class ownership changes*.
3. **Graph-Tool / NetworkX / Louvain C++ libraries:** Algorithms for community detection and graph clustering that inspire our `optimizer` module.
