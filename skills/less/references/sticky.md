# Sticky caps

`set` holds a length cap across turns. It is carried in conversation context —
there is no state file, no hook, and nothing agent-specific about it.

## The cap governs the response, never the work

This is the rule the whole mode depends on. Under `/less 1 set`, the next
request still gets the full investigation: every file read, every test run,
every check that request deserved. What changes is the report, not the rigour.

A capped turn is therefore **not** a compression. Rule 1 in `SKILL.md`
("compress, never recompute") applies to the `/less` command itself, which
re-renders a response that already exists. It does not apply to a capped turn,
where the work is genuinely happening and the cap only decides how much of it
reaches the page.

Never let a cap become a reason to skip a step, guess instead of checking, or
stop asking a question the work needs answered.

## `set`

`/less 2 set` does both halves: it compresses the previous response to two
sentences now, and caps every later response at two sentences until unset.

Acknowledge activation exactly once, appended to that first compressed
response as plain parenthetical text — never fenced, because the one free code
block belongs to the payload. The acknowledgment does not count toward the cap.
Write it as `(cap: 2 sentences — /less unset to remove)`, and add the
limitation below to it the first time in a session: `(cap: 2 sentences — /less
unset to remove; it fades if the context compacts)`.

Never repeat it on later turns. A cap that announces itself every turn spends
the budget it was meant to save.

A second `set` replaces the first; acknowledge the new value in the same
one-time form.

## `unset`

Drop the cap and confirm in one sentence — "Cap removed." With no cap active,
say so in one sentence and change nothing.

## Precedence

A one-off `/less N` while a cap is active applies to that invocation only; the
cap resumes on the following turn. This holds in both directions: under a
one-sentence cap, `/less paragraph` gets a paragraph.

## What a cap never suppresses

- **The fidelity floor.** Errors, destructive-action warnings, and the values
  the reader needs still survive, exactly as in `compression.md` — including
  its one allowance, that the floor may bend the cap by a single sentence.
- **A question the work requires.** If something genuinely needs the user's
  decision, ask it. Ask it inside the cap, but ask it.
- **Intermediate status text.** A cap does not forbid a brief progress note
  during a long task. It is not a side channel either: never park the prose the
  cap removed in a status line and call the sentence at the end compliant. The
  reader asked for less to read, not for the same volume relocated. Under a cap
  these get sparser, not busier.

When an answer truly cannot fit — "explain the architecture" under a
one-sentence cap — give the outcome at cap length and stop. The reader set the
cap and can lift it; padding past it is not your call.

## The limitation, stated plainly

The cap lives in conversation context. It can fade when the context is
compacted, and it does not survive into a new session. Nothing recovers it
automatically.

The acknowledgment carries this the first time a cap is set in a session, which
is why it has the longer form above. If a cap seems to have stopped applying,
that is the reason — re-issue `/less N set`.
