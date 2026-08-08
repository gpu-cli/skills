---
name: less
description: "Re-renders the previous response shorter: one sentence, two, or a paragraph. Use for tldr, condense, too long, brevity cap."
---

# Less

Say the last thing again, shorter. Compress what was already said — never redo
the work that produced it.

```text
/less [N | paragraph] [set]
/less unset
```

| Argument | Do |
| --- | --- |
| *(none)* | Compress the previous response to one paragraph |
| `N` | Compress it to at most N sentences |
| `paragraph` | Compress it to at most one paragraph |
| `… set` | Compress now, then cap every later response until unset — [references/sticky.md](references/sticky.md) |
| `unset` | Drop the active cap, confirm in one sentence |
| anything else | One sentence of usage, nothing more |

A bare `set` takes the paragraph default, so `/less set` is `/less paragraph
set`.

## Rules

1. **Compress, never recompute.** The source is the last message the reader
   actually received — not tool output, not a status note behind it. No tool
   calls, no re-reading, no fresh reasoning, no claim that was not already made.
2. **Lead with the outcome.** The first sentence answers what happened or what
   the answer is.
3. **The cap is hard.** N means at most N sentences; `paragraph` means one
   paragraph. Prose at every level: no headers, no bullets, no preamble. One
   claim per sentence — a run-on that obeys the letter of the cap has failed it.
4. **Keep what bites.** Errors and failures, warnings about destructive or
   irreversible actions, risks the reader is walking toward, what they must do
   next, and the concrete values those depend on — numbers, paths, commands,
   URLs. Fold them into the sentences you have; never spend budget announcing
   them separately.
5. **One code block is free** when the payload *is* a command or snippet. The
   prose around it still counts.
6. **Cut in this order:** process narration, roads not taken, hedging that
   carries no risk or decision of its own, background.

Rules 1 and 4 outrank the rest, and their collision has exactly one release
valve: an error, a destructive-action warning, or the reader's required next
step that truly cannot fold in may bend the cap by a single sentence, once per
response — concrete values never earn the bend. The full response is still on
screen, so point at what will not fit ("the four steps above") rather than
dropping it silently.

**A cap governs the response, never the work.** A capped turn still gets the
full investigation — every file read, every test run, every check that request
deserved. Only the report is short. A cap is never a reason to skip a step,
guess instead of checking, or drop a question the work needs answered.

[references/compression.md](references/compression.md) carries the counting
rules, the worked examples, and the degenerate cases. Read it when the source
is more than plain prose, or when the cap is one sentence.

## Edge cases

- **Nothing substantive to compress** — the previous turn was a greeting, an
  acknowledgment, or empty: say so in one sentence and answer nothing new. A
  question is substantive: compress it, never answer it on the reader's behalf.
- **Already within the cap**: return it unchanged. Do not pad it, and do not
  announce that it already fit.
- **Previous response was itself `/less` output**: compress again from it.
