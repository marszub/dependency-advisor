# Design Documents Index

This directory is the permanent text output of the project's design work: every
significant architectural decision, algorithm, and harness change is recorded
here so future developers and AI agents can recover the reasoning without
re-deriving it.

Read the document that matches your task before changing code:

| # | Document | Covers |
|---|----------|--------|
| 1 | [General Design](1_general_design.md) | Goals, vision, and the high-level problem statement |
| 2 | [C++ Analysis](2_cpp_analysis.md) | Node, edge, and group model for C++ code |
| 3 | [Clang Integration](3_clang_integration.md) | AST extraction rules, matchers, and the `src/extractor/` boundary |
| 4 | [Math and Algorithms](4_math_and_algorithms.md) | Objective function, modularity, Louvain/HAC, cost model |
| 5 | [Build Integration](5_build_integration.md) | CMake/Make/Bazel/Qbs and compile-database handling |
| 6 | [Infrastructure and Project Plan](6_infrastructure_and_project_plan.md) | Bazel, C++23, CI, UX/UI, and agent guidelines |
| — | [Harness Configuration (draft)](../tmp/harness_design.md) | OpenCode harness design: agents, commands, skills, permissions |

Drafts and design spikes live in `docs/tmp/`. A draft graduates into this
directory (renumbered, indexed above) once the decision is accepted. Open
follow-up work is tracked in
[harness_todo.md](../tmp/harness_todo.md).

## Writing a design document

Use the workflow in `.opencode/skills/design-documentation/SKILL.md`. Every
document must include: context, decision, alternatives considered, trade-offs,
affected modules, and a verification plan. Prefer updating an existing document
over creating a near-duplicate, and update this index in the same change.
