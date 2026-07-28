# Decision row format

The canonical contract for one decision record. The `logic track` skill owns the
plain-language version; this is the full field reference.

## Fields

| field    | required | meaning |
|----------|----------|---------|
| ts       | auto     | ISO8601 UTC timestamp; the timeline axis |
| actor    | auto/override | who decided: `user`, a person's name, an agent id, or `inferred` (view-only) |
| phase    | optional | workstream or component (`flame`, `auth`) |
| decision | yes      | what was chosen or done, one line |
| why      | optional* | the reason in plain words; empty ⇒ a stub |
| confidence | optional | actor's perceived confidence: `high` \| `medium` \| `low` \| `unknown`; defaults to `unknown` |
| evidence | optional | a pointer: commit SHA, `file:line`, PR number, artifact path |
| result   | optional | outcome/state: `tests green`, `reverted`, `60fps`, `INCONCLUSIVE`, `open` |
| kind     | auto     | `stub` \| `manual` \| `agent` \| `inferred` |
| sha      | auto     | commit the row is anchored to, when applicable |
| worktree | auto     | repo root that wrote the row (the stream axis) |
| branch   | auto     | logical branch the row is scoped to |

\* A row with no `why` is a **stub**: a mechanical capture awaiting enrichment.
`logic show` renders it flagged; the enrichment gate asks for a why.

## Rules

- **One decision per row.** If it won't fit on one line, it isn't crisp yet.
- **Append-only.** A wrong call gets a new superseding row; never rewrite.
- **Evidence is a pointer, not prose.** A reviewer follows it; they don't read it.
- **Confidence is perceived, not proven.** It records the actor's assessment at
  the time and never overrides contrary evidence or decision-quality review.
- **Plain language.** Write it the way you'd tell a teammate. No AI-speak, no
  jargon tags. `explored options first, this was a one-way door`, not a label.
- **Attribution is honest.** `actor` is who actually decided. Never attribute an
  invented rationale or confidence to the user — leave a pending row with
  `confidence=unknown` instead.
- **Inferred rows are never stored.** They exist only in a `logic show`
  reconstruction view, marked `actor=inferred`, with hypothesis-phrased whys
  and `confidence=unknown`.

## Storage encodings

**beads** (default): a `decision` bead, created then closed. `title=decision`,
`description=why`, `labels=[logic:<branch-slug>, logic-stub?]`, and the remaining
fields in metadata JSON. Reads use `bd query ... --all` to include closed rows.

**TSV** (fallback): tab-separated, one file per writer at
`.logic/audit/<branch-slug>/<actor-slug>.tsv`, header:

```
ts	actor	phase	decision	why	evidence	result	kind	sha	worktree	confidence
```

The TSV log is strictly append-only, so **enrichment arrives as a superseding
row**: a `kind=enrich` row carrying the same `sha` and `decision` as the stub it
explains. Readers collapse each `(sha, decision)` group to its enriched row.
Rows with no `sha` are never collapsed — two decisions logged in the same second
by the same actor are distinct and both survive, because row identity includes a
content component, not just timestamp and actor.

The `confidence` column is appended so existing ten-column TSV rows remain
readable; collectors treat a missing value as `unknown`.

Cells are single-line; the writer strips stray tabs/newlines and prefixes any
cell starting with `=`, `+`, `-`, or `@` with a quote so a spreadsheet open can't
execute it as a formula.
