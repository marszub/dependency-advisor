# Design: OpenCode Harness Configuration for Dependency Advisor

**Status:** Draft (implemented and verified; awaiting review before promotion to
`docs/design/`)
**Date:** 2026-11-08
**Scope:** `opencode.json`, agent instruction files, project skills/commands,
formatter/linter integration, verification scripts, and cross-harness pointers.

---

## 1. Context

Dependency Advisor is a C++23 static-analysis tool whose defining architectural
rule is that Clang/LLVM never leaks out of `src/extractor/`. The project is
model-agnostic: it must be workable from OpenCode, Claude Code, Cursor, Copilot,
or a plain CLI loop. At the time of writing the repository has:

- one C++ source file (a Clang LibTooling extractor) and no build workspace
  (`MODULE.bazel`, `BUILD.bazel`, `WORKSPACE` absent);
- no unit or integration test suites, no compiled `dependency-advisor` binary,
  no CI workflow, no `Dockerfile`;
- design documents 1–6 under `docs/design/` and drafts under `docs/tmp/`;
- an installed OpenCode 2.2.5 service, `clang-format` 22.1.8, `clang-tidy`, and
  Python 3.14; **no** `bazel` and **no** `pytest`.

The harness therefore has to deliver value *before* the compiler pipeline exists,
without pretending that unbuildable checks pass.

### Goals

1. Load project rules automatically for any session opened anywhere in the repo.
2. Encode the module boundaries so agents cannot silently violate them.
3. Give agents short, repeatable workflows for verification, formatting, review,
   boundary auditing, and design documentation.
4. Make the "write decisions into `docs/`" policy executable, not aspirational.
5. Stay model- and harness-agnostic; no provider or model is pinned.
6. Produce verifiable evidence for every check, and document anything that
   cannot be implemented yet.

### Non-goals

- Installing Bazel, pytest, or a C++ toolchain in this change.
- Implementing the analysis engine or its tests.
- Pinning a specific LLM, provider, or subscription.
- Replacing human review or committing/pushing on the user's behalf.

---

## 2. How OpenCode V2 loads this configuration

Understanding discovery matters because the repository is often opened from
`src/` or `tests/`, not only from the root.

- OpenCode searches the current directory **and every ancestor** for
  `opencode.json(c)` and `.opencode/opencode.json(c)`.
- Discovery order: direct `opencode.json` files from the farthest ancestor to
  the closest, then `.opencode` configs in the same order. `.opencode` overrides
  direct config at the same level. System config outranks both.
- `AGENTS.md` is loaded from the workspace directory up to the home directory
  (or project root for workspaces outside home). Nested `AGENTS.md` files are
  loaded when the agent reads files or lists directories below the workspace.
- Config and instruction changes hot-reload; `/reload` forces a full reload.
- V2 recognizes `AGENTS.md` only (not `CLAUDE.md`), so other harnesses need
  explicit pointer files (see I-04).

Consequence: placing `opencode.json` and `AGENTS.md` at the repository root
covers sessions started in `src/extractor/`, `tests/`, or any deeper directory.

---

## 3. Design overview

```text
Repository root
├── AGENTS.md                     # always-on project guidance (single source of truth)
├── CLAUDE.md                     # thin pointer for Claude Code
├── .cursor/rules/*.mdc           # thin pointer for Cursor (alwaysApply)
├── .github/copilot-instructions.md  # thin pointer for Copilot
├── opencode.json                 # harness: agent, commands, permissions, formatter, watcher
├── .clang-format / .clang-tidy   # format/lint policy used by the formatter and agents
├── scripts/
│   ├── check_boundaries.py       # mechanical Clang/LLVM containment check
│   └── verify.sh                 # one entry point: boundaries, format, Bazel, pytest, git hygiene
├── .opencode/skills/
│   ├── design-documentation/SKILL.md
│   └── module-boundary-audit/SKILL.md
├── src/AGENTS.md                 # module-scoped rules, loaded when src/ is explored
├── tests/AGENTS.md               # testing rules, loaded when tests/ is explored
├── docs/design/README.md         # design index, loaded as an instruction
└── docs/tmp/                     # drafts (this document)
```

---

## 4. Improvement catalogue

Each item states: what it is, how it is implemented, how it helps agents, and
what gets worse. Decisions: **Adopted**, **Deferred**, **Rejected**.

### 4.1 Instructions and context

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-01 | Layered `AGENTS.md` | Root `AGENTS.md`; `src/AGENTS.md` with the module table and non-negotiables; `tests/AGENTS.md` with test policy. Nested files load on exploration. | The module rules appear exactly when the agent enters `src/` or `tests/`, without paying their token cost in unrelated work; local rules can be more specific than global ones. | Duplication with the root file can drift; nested files are not re-read after an edit until a new session or a fresh read; too many layers add prompt noise. Mitigation: keep nested files short and point back to the root. | Adopted |
| I-02 | Explicit instruction index | `instructions: ["AGENTS.md", "docs/design/README.md"]` in `opencode.json`. `docs/design/README.md` is a one-page map of design documents. | Agents discover the design corpus without a `glob`; the index states which document to read before changing a subsystem. | Listing `AGENTS.md` may inject it twice (discovery + explicit list), costing tokens; the index itself can drift from the directory. | Adopted |
| I-03 | `docs/` as permanent text output | `design-documentation` skill defines locations, required sections, and update rules; `/design` command wraps it; root `AGENTS.md` §6.5 makes it mandatory. | A design decision produces a durable artifact instead of a chat-only rationale; future agents recover *why*, not just *what*; reduces re-derivation and contradictory refactors. | Documentation can lag code; agents may over-document trivia or create near-duplicates. Mitigation: "update before create", index update in the same change, and a required-sections checklist. | Adopted |
| I-04 | Cross-harness pointers | `CLAUDE.md`, `.cursor/rules/dependency-advisor.mdc` (`alwaysApply: true`), `.github/copilot-instructions.md`, each a short pointer to `AGENTS.md` plus the non-negotiables. | The same rules apply in Claude Code, Cursor, and Copilot without maintaining three full copies. | Pointers can still drift; the target tools are not installed here, so their parsing is unverified. Cursor's rule schema may change. | Adopted (unverified in those tools) |
| I-05 | Loading all design docs as instructions | Would add `docs/design/*.md` to `instructions`. | Every design detail always available. | Documents 1–6 are large; loading them every session wastes context and dilutes attention. Agents can read the indexed document on demand instead. | Rejected |
| I-06 | Nested `AGENTS.md` per file/module (`src/graph/AGENTS.md`, etc.) | One file per directory. | Maximum locality. | Five-plus files to keep in sync for a repository that currently has one source file; over-engineering. Revisit when `src/graph/` and `src/optimizer/` exist. | Deferred |

### 4.2 Agents

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-07 | Default implementation agent | `agents.cpp-expert` (`mode: primary`) and `default_agent: "cpp-expert"`. Its system prompt restates the non-negotiables and the verification contract. | Every new session starts with the project's rules and the expected done-criteria, instead of a generic coding agent. | Users who expect the stock `build` agent (or a plan-first flow) get a project-specific persona; a long system prompt costs tokens; the prompt can become stale versus `AGENTS.md`. Mitigation: keep it a short restatement, not a second manual. | Adopted |
| I-08 | Read-only reviewer subagent | `reviewer`, `mode: subagent`; denies `edit`, `subagent`, and all shell except `git status/diff/log/show`; prompt requires severity-ordered findings and a verdict. | Cheap second pass on correctness, boundary violations, and missing tests; cannot accidentally modify work; fresh context avoids the implementer's rationalizations. | Fresh context lacks the conversation's intent; it cannot run tests (by design) so it cannot prove a bug; every review is a model call. | Adopted |
| I-09 | Documentation subagent | `design-documenter`, `mode: subagent`; denies all edits except `docs/**`; prompt encodes the required document sections. | Design write-ups cannot accidentally touch source; enforces the "docs as output" policy through permissions, not just prose. | It cannot inspect build output beyond read tools; it may over-document; docs-only edits still need review. | Adopted |
| I-10 | Extractor-scoped subagent | `clang-extractor`, `mode: subagent`; edits allowed only under `src/extractor/`, `tests/unit/`, `tests/fixtures/`. | Parallelizes AST work while making "Clang code stays in the extractor" the path of least resistance. | Cannot fix a necessarily cross-module interface change; may duplicate the primary agent's work; permissions are path-based, not semantic. | Adopted |
| I-11 | More role agents (`graph-expert`, `cli-expert`, `ci-expert`) | Additional subagents with narrow prompts. | Sharper specialization. | Four agents already cover the current surface; each adds prompt maintenance and choice overhead. Revisit when the modules exist. | Deferred |
| I-12 | Pin a model / provider | `model` and `providers` in project config. | Reproducible behavior across a team. | Violates the model-agnostic requirement; project config would override a user's local provider choice; model IDs change. Use the user/global config or `--model` instead. | Rejected |
| I-13 | Per-agent `steps`, `request`, `hidden`, `color` | Agent fields. | Step caps can stop runaway loops; headers/body overlays can tune sampling. | V2 preserves `request` but does not yet send it; step caps can truncate legitimate long refactors; cosmetic fields add no engineering value. | Rejected |
| I-14 | Experimental subagent nesting (`subagent_depth > 1`) | `experimental.subagent_depth`. | Deeper delegation. | Experimental, can change without notice; harder to audit; default depth 1 is sufficient. | Rejected |
| I-15 | Background subagents by default | Commands with `subagent: true`; tools with `background: true`. | Keeps the parent responsive during long reviews. | Only `/review` benefits today; background results need a follow-up turn, which complicates the loop. `/review` uses it; nothing else does. | Adopted selectively |

### 4.3 Commands

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-16 | `/verify` | Prompt template: run `./scripts/verify.sh`, then `git diff --check`/`git status --short`, report exit codes and file:line failures. | One command replaces a multi-step ritual; makes "show evidence" the default; works even while Bazel is absent (reports skips). | A prompt, not a shell alias, so it costs a model turn; the script can drift from CI. | Adopted |
| I-17 | `/format` | Prompt template: collect changed C/C++ files, run `clang-format -i`, show `git diff`, do not stage. | Enforces the "format but review the diff" rule; avoids formatting the whole tree. | `git diff --name-only` misses untracked files unless the agent also checks `git status`; formatting can touch unrelated lines in a file. | Adopted |
| I-18 | `/design` | Prompt template: invoke `@design-documentation`, update or create a numbered doc, update the index. | Turns ad-hoc decisions into indexed docs with required sections. | Another model turn; may over-produce documents; depends on the skill being discoverable. | Adopted |
| I-19 | `/review` | Command with `agent: reviewer`, `subagent: true`. | One-step read-only review with a verdict. | **Shadows the built-in `/review` command** (project commands override built-ins), so users lose the stock review behavior. Documented trade-off; rename to `/review-ai` if the built-in is preferred. | Adopted with caveat |
| I-20 | `/boundary-audit` | Prompt template invoking `@module-boundary-audit` and `scripts/check_boundaries.py`. | A repeatable, mechanical boundary check plus semantic greps. | Depends on script exit codes; cannot detect architectural coupling that is not textual. | Adopted |
| I-21 | Shell blocks in command templates (`` !`cmd` ``) | Execute shell at command expansion. | Zero-turn data collection (e.g., embed `git diff` in the prompt). | Shell blocks run **outside** the agent permission flow; argument injection is possible; breaks the "review before execute" safety model. | Rejected |
| I-22 | File-based commands under `.opencode/commands/` | Markdown files instead of JSON. | Easier multi-line prompts and per-command frontmatter. | Two registries to search; JSON keeps the whole harness in one reviewable diff. Revisit if command count grows. | Deferred |
| I-23 | Command-specific model/agent overrides | `model`, `agent` fields. | e.g., a cheaper model for `/format`. | Model IDs are not portable; contradicts model-agnosticism. Only `agent` is used (reviewer). | Partially adopted |

### 4.4 Skills

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-24 | `design-documentation` skill | `.opencode/skills/design-documentation/SKILL.md` with locations, required sections, and done criteria. | Loads a long procedure only when documenting; keeps the always-on prompt small; makes the docs policy executable. | Discovered by description, so a vague request may not trigger it; skill text can drift from the index. | Adopted |
| I-25 | `module-boundary-audit` skill | `.opencode/skills/module-boundary-audit/SKILL.md` with the script and semantic greps. | Encodes the non-negotiable boundary as a repeatable audit, including non-textual smells (process execution, rendering in pure modules). | Greps are heuristics; false positives/negatives; one more file to maintain. | Adopted |
| I-26 | More skills (build, release, profiling) | Additional `SKILL.md` directories. | Task-specific checklists. | No stable procedures yet; premature. Add when the workflow exists. | Deferred |
| I-27 | Hide skills from auto-invocation | `metadata.opencode/autoinvoke: false`. | Reduces prompt noise. | Two small skills are useful for discovery; hiding them would make agents less likely to use them. | Rejected |

### 4.5 Permissions and safety

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-28 | Ask-by-default shell with narrow allows | Global `permissions`: `shell * → ask`; allow read-only Git, `bazel build/test/run`, `clang-format`, project scripts, pytest; ask for `clang-tidy`, `git commit`; deny `git push`, `git reset --hard`, `git clean`, `rm -rf`, `sudo`. | Agents run the verification loop without prompts, while destructive or irreversible actions stay blocked; the committed policy is visible to reviewers. | Prefix matching is not a sandbox; `bazel run` can execute arbitrary project binaries; legitimate commands outside the allowlist interrupt the flow; `git commit` still asks (intentional). | Adopted |
| I-29 | Deny edits to `.git/` | `edit .git/* → deny`. | Prevents accidental repository corruption. | Does not cover shell-based writes; shell rules are the backstop. | Adopted |
| I-30 | Ask for external directories | `external_directory * → ask`. | Stops silent reads/writes outside the repo. | Adds a prompt for legitimate reference material outside the tree; use `references` or copy fixtures in. | Adopted |
| I-31 | Org-level `policies` | Top-level `policies` / managed config. | Hard denies that project files cannot override. | This is an organization/Console concern, not a repository concern; a project-level policy adds no enforcement against a user who edits the project config. | Rejected (project scope) |
| I-32 | Saved "allow always" approvals | Runtime UI choice, stored per project. | Fewer repeated prompts. | Broad approvals can silently widen the allowlist; they are durable and easy to forget. Review with `opencode api get /api/permission/saved` when in doubt. | Adopted as user-controlled |
| I-33 | Secrets via env/file substitution | `{env:NAME}` / `{file:path}` in provider and MCP config. | Keeps secrets out of version control. | Substitution silently becomes empty when unset; no project-level secrets are needed yet. | Adopted as policy, unused |
| I-34 | Deny web tools | `webfetch`/`websearch` deny rules. | Reduces exfiltration and distraction. | Agents benefit from upstream C++/Clang documentation; default policy already requires no secret exposure. | Rejected |

### 4.6 Toolchain integration

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-35 | Formatter after edits | `formatter: true`; `.clang-format` (Google, 100 cols, 4-space indent). | Agent edits land already formatted; no separate formatting pass for style-only issues. | Reformatting can touch unrelated lines in a file; `clang-format` has no `c++23` Standard value (pinned `c++20`); formatter failures are logged and do not block the edit. | Adopted |
| I-36 | Static analysis config | `.clang-tidy` with `bugprone-*`, `modernize-*`, `performance-*`, `readability-*`, naming options; `clang-tidy` permission is `ask`. | Agents can run the same lint policy humans use; naming options encode the Google style. | Requires `compile_commands.json` for real analysis (absent until Bazel generates it); check sets can be noisy; `-fix` modifies files, hence `ask`. | Adopted (config verified; analysis deferred) |
| I-37 | Watcher ignores build outputs | `watcher.ignore`: `bazel-*`, `build/**`, `.cache/**`, `__pycache__/**`, `.pytest_cache/**`, `compile_commands.json`. | Avoids filesystem churn and context invalidation when Bazel/Python write artifacts. | A real source directory named `build/` would be ignored; patterns are project-specific. | Adopted |
| I-38 | One verification entry point | `scripts/verify.sh` with `--strict`; runs boundaries, clang-format, Bazel (conditional), pytest (conditional), `git diff --check`. | Agents and humans share one command; missing toolchains are explicit skips, not false passes; `--strict` gives CI semantics. | Bash 4 `mapfile`; `git ls-files` requires a Git tree; strict mode fails today (no Bazel), which is intentional but can surprise. | Adopted |
| I-39 | Mechanical boundary check | `scripts/check_boundaries.py` with `--root` for testability. | Catches Clang/LLVM leakage in CI and before commit; negative/positive fixtures prove it works. | Regex-based: misses indirect includes, macros, or generated code; scans only `src/` and `tests/`. | Adopted |
| I-40 | Bazel build/test integration | `bazel build/test` in allowlist and `verify.sh`. | Real unit/integration verification once the workspace exists. | **No Bazel workspace or binary exists**, so the check is a skip today; `--strict` fails. Follow-up: add `MODULE.bazel`, `BUILD.bazel`, GoogleTest targets. | Deferred (blocked) |
| I-41 | pytest integration | `python3 -m pytest tests/integration -q` when the suite exists. | End-to-end CLI/JSON verification. | No `tests/integration/` and no pytest in this environment; strict mode fails when the suite exists but pytest is missing. | Deferred (blocked) |
| I-42 | Docker parity | `Dockerfile` with LLVM/Bazel. | Identical toolchain on any host. | Dockerfile does not exist; building images is slow; not needed for the harness to work. | Deferred (blocked) |
| I-43 | GitHub Actions CI | `.github/workflows/ci.yml` running `verify.sh --strict`, clang-tidy, ASan/UBSan. | Enforces the same contract outside the agent loop. | No workflow yet; CI requires Bazel and a buildable target. | Deferred (blocked) |
| I-44 | Tighten `tool_output` | `tool_output.max_lines/max_bytes`. | Bounds compile-error dumps. | Defaults (2000 lines / 50 KiB) are already reasonable; C++ template errors can exceed them, and truncation may hide the relevant line. | Deferred |
| I-45 | Custom compaction policy | `compaction.auto/keep/buffer`. | Preserves more recent design context. | Defaults are adequate; tuning without measurements is guesswork. | Rejected |
| I-46 | Request warming | `warming: true`. | Lower first-token latency. | Costs tokens/money on idle sessions; irrelevant to correctness. | Rejected |
| I-47 | Disable snapshots | `snapshots: false`. | Saves disk. | Undo/revert is a safety net for agent edits; keep the default (enabled). | Rejected |

### 4.7 Extensions and context sources

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-48 | MCP servers (Context7, clangd bridge, issue tracker) | `mcp.servers`. | Fresh library docs; symbol navigation; issue lookup. | Extra processes/OAuth/network surface; MCP tools consume context; a clangd MCP would duplicate `clang-tidy`/Clang tooling; none is configured or tested. Add on demand. | Rejected for now |
| I-49 | `references` to external docs | `references` entries. | Named outside context. | Design docs are inside the repo; `instructions` covers them. External references would need credentials/large checkouts. | Rejected |
| I-50 | Plugins | `plugins` entries. | Automate repeated hooks (e.g., post-verify). | No plugin requirement yet; plugin API is the intentional V2 breaking surface; adds supply-chain risk. | Rejected |
| I-51 | LSP / clangd integration | No V2 project-config field in the current docs. | In-editor diagnostics. | Not available through `opencode.json`; agents can run `clang-tidy`/`clang-format` directly. Use clangd in the user's editor instead. | Rejected (unsupported) |
| I-52 | Browser / image generation | Desktop browser tools; `experimental.image_generate`. | Visual checks, diagrams. | Not needed for C++ analysis; experimental; permissions disabled by default for browser. | Rejected |
| I-53 | ACP / HTTP API / SDK | `opencode serve`, `opencode api`. | Automation and CI integration. | Overkill for day-to-day development; used here only to inspect the loaded config/commands/skills. | Deferred |
| I-54 | Web search provider config | `websearch.provider`. | Deterministic search. | Provider availability differs per user; defaults are fine. | Rejected |
| I-55 | Worktrees | `worktree.directory` config; `worktree_create` tool. | Parallel isolated tasks. | No need yet; the default data-directory location is fine. Revisit for parallel agent fleets. | Deferred |
| I-56 | Schedules / background jobs | `experimental` schedule API. | Recurring checks. | CI should own recurring verification, not an agent session. | Rejected |

### 4.8 Experimental and CLI-only settings

| ID | Improvement | Implementation | Benefit for agents | Disadvantages / risks | Decision |
|----|-------------|----------------|--------------------|-----------------------|----------|
| I-57 | Todo tracking tool | `experimental.todo: true`. | Multi-step plans become visible. | Experimental; the harness already uses background goals/commands; can be enabled per user. | Deferred |
| I-58 | Background compaction | `experimental.background_compaction: true`. | Removes compaction pauses. | Experimental; long C++ sessions may still compact unpredictably. | Rejected |
| I-59 | Location idle timeout | `experimental.location_idle_timeout`. | Frees idle services. | Default 60 minutes is fine. | Rejected |
| I-60 | CLI themes/keybinds/settings | `~/.config/opencode/cli.json`. | Personal ergonomics. | CLI-only, user-specific; project config cannot set them and should not. | Rejected (not project config) |
| I-61 | `update`, `username`, `shell`, `media` | Config fields. | Housekeeping. | `update` is global-only; `username` is cosmetic; `shell` is host-specific; media defaults are fine. | Rejected (out of scope) |

---

## 5. Tools, libraries, and languages in context

### 5.1 Languages

| Language | Role | Included? | Why / why not |
|----------|------|-----------|----------------|
| C++23 | Product implementation | **Included** | The harness commands, formatter, linter, agents, and module rules all target C++23. |
| Python 3 | Boundary checker and integration tests | **Included** | `scripts/check_boundaries.py` is Python; pytest is the chosen integration runner. Requires Python ≥3.9 syntax (`list[str]`, `Path`). |
| Bash | `scripts/verify.sh`, agent shell commands | **Included** | Universal on Linux/macOS CI; the script uses `mapfile` (Bash 4+) and is explicitly run with `bash`. |
| Markdown/JSON | Instructions, design docs, harness config | **Included** | `AGENTS.md`, skills, design docs; `opencode.json` is JSON (not JSONC) so it validates with plain `json.tool`. |
| PowerShell | Windows shell | **Excluded** | The design targets Ubuntu/macOS CI; OpenCode's scanner supports it, but the verification script does not. Add a PowerShell port only if Windows becomes a supported host. |
| YAML | CI workflows | **Deferred** | No `.github/workflows/ci.yml` yet. |
| TypeScript/JavaScript | Plugins, future web UI | **Excluded** | No plugin or web layer in scope. |

### 5.2 Build, test, and analysis tools

| Tool | Role | Included? | Why / why not |
|------|------|-----------|----------------|
| Bazel | Primary build/test system per design doc 6 | **Included in config, not installed** | Allowlisted in permissions and invoked by `verify.sh` when a workspace exists. No `MODULE.bazel`/`BUILD.bazel`/binary, so the check skips today and `--strict` fails. This is documented, not hidden. |
| clang-format | Formatting, post-edit formatter | **Included** | Installed (22.1.8); `.clang-format` present; `formatter: true` verified end-to-end. |
| clang-tidy | Static analysis | **Included (config), deferred (run)** | `.clang-tidy` validated with `--dump-config`; real analysis needs `compile_commands.json`. `-fix` requires approval. |
| GoogleTest | Unit tests | **Referenced, not wired** | The harness prompts and test rules require GoogleTest, but there are no Bazel targets or tests yet. |
| pytest | Integration tests | **Included conditionally** | `verify.sh` runs it when `tests/integration/` exists; pytest is absent in this environment. |
| Git | Diff/status/history, hygiene | **Included** | Read-only Git is allowlisted; `git commit` asks; `git push`/`reset --hard`/`clean` are denied. `verify.sh` runs `git diff --check`. |
| Docker | Reproducible toolchain | **Excluded (for now)** | No `Dockerfile`; deferred alongside the Bazel workspace. |
| GitHub Actions | CI | **Excluded (for now)** | No workflow; deferred until a buildable target exists. |
| `jq` / `curl` | Ad-hoc verification | **Excluded from harness** | Used only during this design's verification; agents do not need them in the loop. |
| OpenCode CLI/API | Config inspection, command/skill registration | **Included as verification** | `opencode debug config|agents`, `opencode api`, `opencode serve` were used to prove the config loads. Not part of the daily workflow. |

### 5.3 Project libraries

| Library | Role | Included? | Why / why not |
|---------|------|-----------|----------------|
| Clang LibTooling / LLVM | AST extraction | **Included, confined** | Core product dependency; allowed only in `src/extractor/` and enforced by `check_boundaries.py`. |
| GoogleTest | Unit-test framework | **Included (future)** | Required by the design; no Bazel target yet. |
| CLI11 | CLI parsing | **Excluded from harness** | A future `src/cli/` dependency; no harness integration needed. |
| nlohmann/json | JSON serialization | **Excluded from harness** | A future CLI dependency; agents must not render JSON in core modules. |
| pytest | Integration assertions | **Included conditionally** | See above. |
| `std::expected` | Error propagation | **Policy, not a library** | Encoded in agent prompts and `AGENTS.md`; enforced by review, not tooling. |
| Community-detection libs (Louvain/Leiden) | Optimizer | **Excluded from harness** | Not selected/implemented yet; no tool decision to make. |

### 5.4 Feature-to-tool mapping

| Harness feature | Tools/languages included | Tools affected/excluded | Justification |
|-----------------|--------------------------|-------------------------|---------------|
| Layered instructions | Markdown, `AGENTS.md` discovery | — | Zero runtime dependencies; works in every harness. |
| Default agent + subagents | OpenCode agent runtime, project prompts | Model/provider excluded | Agents are prompt + permissions; no model is pinned. |
| Commands | OpenCode command registry, Bash/Python indirectly | Shell-block expansion excluded | Prompt templates keep execution inside the permission flow. |
| Skills | Markdown, Python script | Third-party skill catalogs excluded | Local, reviewable skills only. |
| Permissions | OpenCode sandbox/scanner, Git, Bazel, clang tools | `sudo`, force-push, hard reset, `rm -rf` excluded | Irreversible actions are denied; read-only/build actions are allowed. |
| Formatter | `clang-format`, `.clang-format` | Prettier/oxfmt/biome excluded | No JS/TS/JSON/Markdown formatting need; clang-format is the project formatter. |
| Static analysis | `clang-tidy`, `.clang-tidy` | clangd/LSP excluded | No V2 LSP config field; clang-tidy is runnable and auditable. |
| Watcher | OpenCode watcher | Bazel/Python cache dirs excluded from watching | Prevents churn from generated artifacts. |
| Verification | Bash, Python, Bazel, pytest, Git | Docker/CI excluded (deferred) | One local entry point now; CI parity later. |
| Boundary enforcement | Python | Clang itself not required | Static regex check works before the toolchain exists. |
| Cross-harness pointers | Markdown, Cursor MDC | Full duplicated rule sets excluded | Single source of truth avoids drift. |
| Extensions | — | MCP, plugins, references, browser, image, LSP | No current need; each adds context, network, or maintenance cost. |
| Experimental features | — | todo, background compaction, subagent depth, schedules | Unstable; revisit after the core loop stabilizes. |

### 5.5 Exclusions register

Every exclusion above has a reason; the important ones:

1. **Bazel/pytest/Docker/CI are not implemented**, not merely excluded: the
   repository has no build workspace, tests, container, or workflow. The harness
   detects and reports this rather than faking a pass. Follow-up actions are in
   §8.
2. **No model or provider is pinned.** The project is explicitly model-agnostic;
   pinning would override user configuration and break portability.
3. **No MCP servers.** Each server adds a process, credentials, network access,
   and context cost. The project has no external data source requirement yet.
4. **No plugins.** The V2 plugin API is the intentional breaking surface and adds
   supply-chain risk; nothing repetitive enough exists to automate.
5. **No LSP/clangd integration.** There is no documented V2 project-config field
   for LSP; use clangd in the editor or `clang-tidy` from the agent.
6. **No shell blocks in commands.** They bypass the permission flow and are
   injection-prone.
7. **No org policies.** Policies belong to managed/Console configuration; a
   project policy cannot stop a user from editing the project config.
8. **No `docs/design/*.md` glob in `instructions`.** All six documents are large;
   the index plus on-demand reads is cheaper and more focused.

---

## 6. Implemented artifacts

| File | Purpose |
|------|---------|
| `opencode.json` | Default agent, instructions, permissions, 4 agents, 5 commands, formatter, watcher. |
| `AGENTS.md` | Always-on project manual: mission, boundaries, C++23 rules, verification, docs policy, harness shortcuts. |
| `src/AGENTS.md` | Module table and non-negotiables, loaded when `src/` is explored. |
| `tests/AGENTS.md` | Unit/integration/fixture rules, loaded when `tests/` is explored. |
| `docs/design/README.md` | Design-document index; loaded as an instruction. |
| `.opencode/skills/design-documentation/SKILL.md` | Documentation workflow and required sections. |
| `.opencode/skills/module-boundary-audit/SKILL.md` | Boundary audit procedure (script + semantic greps). |
| `scripts/check_boundaries.py` | Clang/LLVM confinement check; `--root` for testability. |
| `scripts/verify.sh` | Boundary + format + Bazel + pytest + whitespace; `--strict`. |
| `.clang-format` | Google style, 100 cols, 4-space indent, `Standard: c++20` (clang-format has no c++23 value). |
| `.clang-tidy` | Modern C++ checks and Google-style naming options. |
| `.gitignore` | Bazel symlinks/outputs, build/cache dirs, `compile_commands.json`, Python caches. |
| `CLAUDE.md`, `.cursor/rules/dependency-advisor.mdc`, `.github/copilot-instructions.md` | Thin cross-harness pointers to `AGENTS.md`. |
| `src/extractor/dependency_extractor.cpp` | Extractor moved from `src/` into the mandated `src/extractor/` and formatted. |
| `docs/design/6_infrastructure_and_project_plan.md` | §3 updated to describe the concrete harness. |

### Change to source layout

The only C++ file lived at `src/dependency_extractor.cpp`, which violates the
documented rule that Clang code lives under `src/extractor/`. It was moved with
`git mv` to `src/extractor/dependency_extractor.cpp` and formatted with
`clang-format` (81 lines changed). No build file references the old path (none
exists), so the move is safe today. The formatting diff was reviewed with
`git diff --stat`; it is style-only plus the `clang-format` include ordering.

---

## 7. Verification evidence

All commands were run in `/home/marszub/projects/dependency-advisor` on
2026-11-08.

### 7.1 Config validity and loading

```text
$ python3 -m json.tool opencode.json >/dev/null && echo "opencode.json: valid JSON"
opencode.json: valid JSON

$ opencode debug config | ...paths...
document /home/marszub/.config/opencode/opencode.json
directory /home/marszub/.config/opencode
document /home/marszub/projects/dependency-advisor/opencode.json
```

A private server started in the project directory (`opencode serve --port 4097`)
reported the merged project document:

```text
path: /home/marszub/projects/dependency-advisor/opencode.json
default_agent: cpp-expert
instructions: ['AGENTS.md', 'docs/design/README.md']
formatter: True
watcher: {'ignore': ['bazel-*', 'bazel-*/**', 'build/**', '.cache/**',
          '__pycache__/**', '.pytest_cache/**', 'compile_commands.json']}
commands: ['boundary-audit', 'design', 'format', 'review', 'verify']
agents: ['clang-extractor', 'cpp-expert', 'design-documenter', 'reviewer']
permissions count: 23
```

### 7.2 Agents and merged permissions

```text
$ opencode debug agents | ...
clang-extractor | mode= subagent | Clang LibTooling specialist constrained to src/extractor/
cpp-expert      | mode= primary  | Primary C++23 implementation agent for Dependency Advisor
design-documenter | mode= subagent | Writes and updates design documents under docs/
reviewer        | mode= subagent | Read-only reviewer for correctness, module boundaries...
```

The merged rules show the intended order, e.g. `reviewer` ends with
`deny edit *`, `deny subagent *`, `deny shell *`, then allows the four read-only
Git commands. `clang-extractor` ends with `deny edit *`, then allows
`src/extractor/*`, `tests/unit/*`, `tests/fixtures/*`.

### 7.3 Commands and skills are registered

After creating a session on the project-scoped server:

```text
$ opencode api --server ... get /api/command
init | guided AGENTS.md setup
review | Review current changes with the read-only reviewer subagent
goal | keep working until an objective is met [pause|resume|clear]
verify | Run the repository verification suite and report exact results
format | Format changed C/C++ files and review the diff
design | Record a design decision under docs/design/
boundary-audit | Audit Clang/LLVM leakage across module boundaries

$ opencode api --server ... get /api/skill
opencode | ...
report | ...
browser | ...
design-documentation | Record or update a design decision in docs/...
module-boundary-audit | Verify that Clang/LLVM stays inside src/extractor...
```

Note: project `/review` shadows the built-in `review`; this is the documented
trade-off in I-19.

### 7.4 Boundary check, positive and negative

```text
$ python3 scripts/check_boundaries.py
Boundary check passed: 0 file(s) scanned; Clang/LLVM confined to src/extractor.

# Negative fixture: src/graph/bad.cpp with a Clang include and clang:: usage
$ python3 scripts/check_boundaries.py --root /tmp/opencode/boundary-fixture
src/graph/bad.cpp:1: Clang/LLVM include outside src/extractor/
src/graph/bad.cpp:2: 'clang::' usage outside src/extractor/
Boundary check FAILED: 2 violation(s) in 1 scanned file(s).
exit=1

# Positive fixture: only src/extractor/ok.cpp remains
Boundary check passed: 0 file(s) scanned; Clang/LLVM confined to src/extractor.
exit=0
```

The "0 files scanned" result is expected: after the move, every C/C++ file is in
the allowed directory. The negative fixture proves the detector fires.

### 7.5 Formatter

```text
$ clang-format --dry-run --Werror src/extractor/dependency_extractor.cpp
exit=0

# End-to-end through the agent edit tool (write probe, read back):
write src/extractor/format_probe.cpp: "int  main(){return 0;}"
read  src/extractor/format_probe.cpp:
int main() {
    return 0;
}
```

The probe was deleted afterward. This confirms `formatter: true` + `.clang-format`
is active in the real edit path.

### 7.6 Static-analysis config

```text
$ clang-tidy --dump-config
Checks: "clang-diagnostic-*,-*, bugprone-*, modernize-*, performance-*, readability-*,
         -modernize-use-trailing-return-type, -modernize-avoid-c-arrays,
         -readability-magic-numbers, -readability-identifier-length,
         -readability-function-cognitive-complexity"
HeaderFilterRegex: '(src|tests)/.*'
FormatStyle: file
```

Config parses. Real analysis is deferred until `compile_commands.json` exists.

### 7.7 Verification script

```text
$ ./scripts/verify.sh
== Module boundary check
PASS: module boundary check
== Formatting check (clang-format)
PASS: clang-format (1 file(s))
== Build and unit tests (Bazel)
SKIP: bazel test //... (Bazel or Bazel workspace not configured yet)
== Integration tests (pytest)
SKIP: pytest tests/integration (no suite or pytest unavailable)
== Patch hygiene
PASS: git diff --check (whitespace errors)
== Summary
Failures: 0, skipped: 2
Verification PASSED
exit=0

$ ./scripts/verify.sh --strict
FAIL: Bazel workspace is required in --strict mode
Failures: 1, skipped: 2
Verification FAILED
exit=1
```

Strict-mode failure is the correct result: the repository has no Bazel workspace
yet. It will turn green once §8.1 is done.

### 7.8 Permissions are enforced

During testing, a command beginning with `rm -rf` was rejected by the harness:

```text
{"error":{"type":"permission.rejected","message":"Permission denied: shell"}}
```

This is the intended effect of the deny rule, observed in practice.

### 7.9 Working tree

```text
$ git diff --stat
 .gitignore                             | 15 +++++++
 src/extractor/dependency_extractor.cpp | 81 ++++++++++++----------------------
 2 files changed, 42 insertions(+), 54 deletions(-)

$ git status --short
 M .gitignore
RM src/dependency_extractor.cpp -> src/extractor/dependency_extractor.cpp
?? .clang-format
?? .clang-tidy
?? .opencode/
?? AGENTS.md
?? docs/
?? opencode.json
?? scripts/
?? src/AGENTS.md
?? tests/
```

---

## 8. Gaps, limitations, and follow-up

### 8.0 Implementation status at a glance

| Item | Status | Evidence / blocker |
|------|--------|--------------------|
| `opencode.json` (agent, commands, permissions, formatter, watcher) | Implemented | Loaded by `opencode debug config`; API reports 5 commands and 23 permission rules |
| 4 project agents | Implemented | `opencode debug agents` lists `cpp-expert`, `reviewer`, `design-documenter`, `clang-extractor` |
| 5 commands + 2 skills | Implemented | `/api/command` and `/api/skill` list them on the project server |
| Layered instructions + docs index + pointer files | Implemented | `opencode debug config` shows `instructions`; pointer files exist (not testable in Claude/Cursor here) |
| Boundary enforcement | Implemented and tested | Positive and negative fixtures; `verify.sh` passes |
| Formatter + `.clang-format` | Implemented and tested | Dry-run clean; agent write probe was auto-formatted |
| `.clang-tidy` | Implemented, analysis blocked | `--dump-config` parses; needs `compile_commands.json` |
| `verify.sh` | Implemented and tested | Default passes (0 failures, 2 skips); `--strict` fails as designed |
| Bazel / GoogleTest | Blocked | No `MODULE.bazel`/`BUILD.bazel`, no binary |
| pytest integration suite | Blocked | No `tests/integration/`, pytest not installed |
| Docker / GitHub Actions | Blocked | No `Dockerfile`, no `ci.yml` |
| MCP, plugins, references, LSP, experiments | Excluded | See §4.7/§4.8 and §5.5; no current need or unsupported |

### 8.1 Blocked by missing project infrastructure

Actionable, issue-ready checklist with acceptance criteria:
**[`docs/tmp/harness_todo.md`](harness_todo.md)**.

1. **Bazel workspace.** Add `MODULE.bazel` (LLVM/Clang, GoogleTest, CLI11,
   nlohmann_json via bzlmod), `BUILD.bazel`, and per-module targets. Then
   `bazel test //...` becomes a real check and `verify.sh --strict` can pass.
2. **`compile_commands.json`.** Generate it from Bazel (e.g., via a
   `compilation_database` target or `bazel run //:refresh_compile_commands`) so
   `clang-tidy` can analyze actual translation units.
3. **Unit tests.** Add `tests/unit/` with GoogleTest targets for graph/optimizer;
   the harness already requires them, but they do not exist.
4. **Integration tests.** Add `tests/integration/` with pytest fixtures and a
   built `dependency-advisor` binary.
5. **Dockerfile.** Add the Ubuntu 24.04 + LLVM + Bazel image described in design
   doc 6, then allowlist `docker build/run` if desired.
6. **CI.** Add `.github/workflows/ci.yml` running `./scripts/verify.sh --strict`,
   clang-tidy, and ASan/UBSan, per design doc 6 §6.

### 8.2 Harness limitations

1. **`clang-format` has no `c++23` Standard value** (through v22). `.clang-format`
   pins `c++20` for deterministic parsing; revisit when upstream adds it.
2. **`clang-tidy` needs a compilation database**; without one it can only lint
   single files with guessed flags. Its `-fix` mode asks for approval by design.
3. **Regex boundary check** cannot see macro-expanded includes, generated code,
   or dependency edges in build files. Add a Bazel target dependency check once
   the workspace exists.
4. **Cross-harness pointer files are unverified** here because Claude Code and
   Cursor are not installed. They are intentionally thin to minimize drift.
5. **No end-to-end command execution test.** Commands were verified as
   registered through the API, not executed by a model (which would consume a
   full model turn). `/verify`'s underlying script is tested directly.
6. **`/review` shadows the built-in command.** Rename to `/review-ai` if the stock
   behavior is preferred.
7. **Formatter can reformat unrelated lines.** Review `git diff` after edits; the
   `/format` command and AGENTS.md require it.
8. **`verify.sh` uses Bash 4 `mapfile`.** On macOS's default Bash 3.2 it fails;
   run it with a modern Bash or port the file collection to a `while read` loop.
9. **`strict` mode requires Bazel and pytest.** It intentionally fails today; use
   the default mode while infrastructure is missing.
10. **Project permissions are not a sandbox.** They are prefix-matched rules; a
    determined agent can still run allowed binaries. Human review and CI remain
    the real boundary.
11. **`git diff --check` only inspects tracked diffs**, so whitespace errors in
    brand-new untracked files are not caught by that step (the clang-format step
    does cover new C/C++ files). Add a tracked-only note or `git add -N` before
    checking if this matters.

### 8.3 Future improvements (not implemented)

- MCP server for Clang/LLVM documentation or issue tracking, once a concrete
  source exists.
- A `ci-expert` or `graph-expert` subagent when those modules exist.
- `mkdocs`/`mdbook` rendering of `docs/design/` for humans.
- `experimental.todo` for long multi-step goals, after the core loop stabilizes.
- Worktree-based parallel agents (`worktree.directory`, `worktree_create`) for
  large refactors.
- Windows PowerShell port of `verify.sh` if Windows becomes supported.

---

## 9. Maintenance

- Change harness behavior in `opencode.json`; OpenCode hot-reloads it. Use
  `/reload` to force a full reload.
- Keep `AGENTS.md` the single source of truth. Update `src/AGENTS.md`,
  `tests/AGENTS.md`, and the pointer files only when their scope changes.
- When a design decision changes, update the indexed document and
  `docs/design/README.md` in the same change (use `/design`).
- When the toolchain lands, remove the corresponding "skip" by updating
  `verify.sh` and the allowlist, then flip `--strict` in CI.
- Re-run this document's verification commands after any harness change and
  append the evidence here or in the PR description.
