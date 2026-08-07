---
name: research-spike
description: "Runs a time-boxed technical spike, competitive comparison, or feasibility analysis and writes a cited markdown report. Use for architecture decisions or when evaluating an unfamiliar technology or library."
---

# Research Spike

Time-boxed technical investigation with structured, citation-backed output.

Use for a spike before adopting unfamiliar technology, an architecture decision
record, a comparison of tools or libraries, a feasibility study, a migration or
upgrade assessment, or a survey of best practice in a domain.

## Modes

| Mode | Output emphasizes |
| --- | --- |
| Technical spike | Practical findings, code examples, implementation recommendations |
| Competitive research | Feature matrices, trade-off analysis, selection criteria |
| Feasibility analysis | Constraints, risks, effort factors, go/no-go recommendation |

## Upfront Questions

Use AskUserQuestion to settle three things before researching anything:

1. **Mode** — spike, competitive, or feasibility.
2. **Depth** — quick (high-level overview), standard (actionable depth), or deep
   dive (comprehensive, production-ready guidance).
3. **Scope** — technologies to include or exclude, constraints (budget, team
   expertise, existing stack), and the decision factors that define success.

## Method

1. **Scope** — confirm the question and its boundaries, the key terms, and the
   known constraints.
2. **Plan** — choose sources (web, documentation, the codebase), split into
   sub-questions, and prioritize by the user's decision factors.
3. **Gather** — search and read; explore the codebase where relevant. Record
   every source as you go, not afterwards.
4. **Synthesize** — organize findings by theme, identify patterns and
   trade-offs, derive recommendations from the evidence, and name the gaps.
5. **Write** — produce the report, then check it against the quality gates.

## Anti-Hallucination

- State only what a source explicitly confirms.
- Hedge inferences: "suggests", "likely", "based on X, we can infer".
- Keep opinion visibly distinct from fact.
- Label anything you cannot verify as "unverified" or "needs confirmation".
- When comparing options, include only documented features.

## Output

Write to `research/[topic-slug]/spike-report.md`, progressively as you work
rather than in one pass at the end. Read
[references/report-template.md](references/report-template.md) for the section
template and the quality gates to verify before finishing. Close by telling the
user where the file is and what it concluded.
