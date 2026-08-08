# Less Skill Plan

## Summary

`less` re-renders the agent's previous response at a user-chosen length, on demand,
without redoing any work. It also supports a sticky mode that caps the length of
every subsequent response until unset.

```text
/less 1            # previous response in at most 1 sentence
/less 2            # at most 2 sentences
/less paragraph    # at most one paragraph
/less 2 set        # cap ALL subsequent responses at 2 sentences
/less unset        # remove any active cap
/less              # no argument: default to paragraph
```

## Why this is worth building (2026 landscape)

Every existing control is either global, prospective, or lossy. None of them can
compress the answer you just received:

| Existing option | Why it doesn't cover this |
| --- | --- |
| `outputStyle` setting (the `/output-style` command was deprecated in v2.1.73, removed in v2.1.91) | Global system-prompt swap; takes effect only after `/clear` or a new session. Useless for "shorten that last answer". |
| `/compact` | Compresses the *context window*, not the response shown to the user. |
| "Be concise" in CLAUDE.md / memory | All-or-nothing, and agents drift from it. Also wrong-shaped: often you *want* the full answer first, then a compressed rendering. |
| Typing "shorter please" | Works, but has no contract. The agent decides what "shorter" means, frequently re-runs tools or re-derives the answer, and the preference evaporates next turn. |

The gap `less` fills is **retroactive, bounded compression with a fidelity
contract**: a hard sentence cap, rules for what must survive compression, and an
explicit prohibition on redoing work. Nothing in the current ecosystem
(output styles, tldr-page skills, verbosity flags) does this.

Reality check on scope: this is a small skill. Its value is in the precision of
the contract, not in machinery. Keep it tiny and cheap in context — consistent
with this repo's recent token-accounting work (lean frontmatter description,
detail pushed to `references/`).

## Core behavior contract

These rules are the actual product; they go in `references/compression.md`:

1. **Compress, never recompute.** The source is the previous response text.
   No tool calls, no re-reading files, no new reasoning. If the previous turn
   had no substantive response to compress, say so in one sentence.
2. **Lead with the outcome.** The first sentence answers "what happened" or
   "what's the answer".
3. **Hard cap.** N sentences means N. A paragraph means one paragraph,
   roughly 3–5 sentences, no headers, no lists.
4. **Fidelity floor — these survive compression, inside the budget:**
   - errors, failures, and anything reported as broken
   - warnings about destructive or irreversible actions
   - concrete values the user needs: numbers, file paths, commands, URLs
5. **Code-block exception.** If the previous response's payload *is* a snippet
   or command, one short fenced block may be kept and does not count toward the
   sentence budget. Prose around it still does.
6. **What gets cut first:** process narration, alternatives not chosen,
   hedging, background explanation, anything the user can ask for again.

## Sticky mode (`set` / `unset`)

**Decision (2026-08-08): in-context only, no hooks.** The skill must stay
portable across skill-compatible agents, so no Claude Code-specific machinery.

`set` instructs the agent to apply the cap to every subsequent response until
`/less unset`. Zero machinery. Honest limitation, documented in the skill: the
cap lives in conversation context, so it can fade after compaction and dies
with the session.

Precedence: an explicit one-off `/less N` applies to that invocation only; an
active `set` cap resumes on the following turn. `unset` with no active cap
reports so in one sentence.

## Proposed file tree

```text
skills/less/
  SKILL.md                    # router + the six contract rules, kept short
  references/
    compression.md            # full fidelity rules, examples, edge cases
    sticky.md                 # set/unset semantics, precedence, limitations
  tests/
    selftest.sh               # prose gates: link resolution, portability,
                              # worked examples obey the caps they demonstrate
```

## What eval changed (2026-08-08)

Three fresh agents applied the first draft to realistic long responses and
reported where the instructions were ambiguous. Their findings, and the fixes:

- **The floor contradicted itself.** It listed four items surviving "every
  cap", but the one-sentence bend was granted to two of them. Fixed by ranking
  the floor 1–4, scoping the bend to rows 1–3, and stating that row 4 (concrete
  values) never bends the cap.
- **No priority among competing values.** A source with four paths and three
  counts has no room at N=1. Fixed by ranking values on what the reader cannot
  act without, with the rest pointed at.
- **"No lists" fought "prose the steps".** Fixed by locating the ban in the
  *formatting* — a bullet is a free line that never pays a sentence — while a
  series inside a sentence pays normally.
- **Latent risk fit no floor category.** A bug waiting in production is not an
  error, not a destructive action, not a value. Row 2 was widened, plus:
  hedging that names a risk is not hedging.
- **The anti-smuggling rule had no teeth**, and policed only semicolons and
  dashes, so `and`/`but`/`so` walked straight through — and the file's own
  examples used that loophole. Restated around one *claim* per sentence,
  punctuation-agnostic, with a forty-five word backstop.
- **The sticky acknowledgment was shown fenced**, claiming the one code block
  rule 5 reserves for the payload. Now plain parenthetical text.
- Added a worked example whose payload is a command, since every original
  example was prose and the code-block interaction was the most-questioned rule.

## Non-goals / future ideas

- `/more` (inverse: expand the previous response) — natural sibling, out of scope.
- Word-count or bullet-format targets (`/less words:50`, `/less bullets`) —
  add only if sentence counts prove too coarse in practice.
- Applying to another agent's output or arbitrary pasted text — scope creep.

## Implementation steps

Tracked as a beads epic (see `bd show` for the epic under this title).

1. Scaffold `skills/less/SKILL.md` with frontmatter (lean description), the
   command table, and the six contract rules.
2. Write `references/compression.md` with worked examples (one long tool-heavy
   response compressed to 1, 2, and paragraph forms) and edge cases.
3. Write `references/sticky.md`: `set`/`unset` semantics, precedence,
   documented compaction limitation.
4. Manual eval: run it against real long responses in this repo; tune the
   fidelity rules where the compression drops something that mattered. Run
   `bash scripts/skill-lint.sh` and `bash scripts/selftest.sh`.
5. Update root `README.md` with the skill entry.
