---
name: Design Documentation
description: Record or update a design decision in docs/ so future agents can recover the reasoning
---

# Design Documentation Workflow

Use this skill whenever a design decision is made, an algorithm changes, a module
boundary moves, or the harness configuration changes.

## Where to write

| Situation | Location |
|-----------|----------|
| Durable, accepted design | `docs/design/<N>_<topic>.md` (next free number) |
| Draft, spike, or open question | `docs/tmp/<topic>.md` |
| Change to an existing design | Edit that document; do not create a near-duplicate |
| Harness/tooling change | `docs/tmp/harness_design.md` until accepted, then `docs/design/` |

`docs/` is the permanent text output of the project. Code comments are not a
substitute: decisions that affect architecture, algorithms, build, CI, or agent
workflows belong here.

## Required sections

1. **Context** — the problem, constraints, and what triggered the decision.
2. **Decision** — what was chosen, in one or two paragraphs.
3. **Alternatives considered** — at least the credible ones, and why they lost.
4. **Trade-offs / disadvantages** — what gets worse, and the mitigation.
5. **Affected modules and tools** — exact paths and libraries; note exclusions.
6. **Verification plan** — commands, tests, or evidence that proves it works.

## Rules

- Prefer updating an existing document over creating a duplicate.
- Update `docs/design/README.md` in the same change.
- Link to code paths in backticks (`src/extractor/`), not line numbers that rot.
- Keep documents model-agnostic: no harness-specific phrasing that only one tool
  understands, unless the document is explicitly about the harness.
- Record exclusions with a reason. "Not needed" is not a reason.
- Do not paste secrets, tokens, or machine-specific absolute paths.

## Done criteria

- The document is readable without the conversation that produced it.
- The index links the document.
- Any command in the verification plan was actually run, or its absence is
  explained.
