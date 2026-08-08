# Compression

The detail behind the six rules in `SKILL.md`. Read it when the source is more
than plain prose, or when the cap is one sentence.

## The original is still on screen

You are not replacing the previous response. It sits directly above yours, and
the reader can look at it. That single fact settles most hard calls: when
something will not fit, **point at it** — "the four steps above", "the second
option above" — rather than dropping it silently or reproducing half of it.
Half a procedure is worse than a pointer to a whole one.

It also settles the floor's hardest case. A command buried in a procedure is
both a row 4 value and part of something too big to fit; the pointer wins,
because a value the reader can still see has not been lost. The floor protects
against a reader walking away **unaware**, not against them scrolling up.

Prose and pointer are not equal, though, so do not toss a coin between them.
Prose the steps whenever they fit inside the cap without breaking the clause
bound, and point only when they will not. Prose hands the reader the answer; a
pointer hands them the way back to it.

## The fidelity floor

Four things outrank ordinary detail at every cap, including one sentence. They
are listed in priority order, and that order is what settles a budget fight
between them:

| # | Survives | Because |
| --- | --- | --- |
| 1 | Errors and failures | The reader must not walk away thinking it worked |
| 2 | Warnings about destructive or irreversible actions, and known risks the reader is walking toward | Data loss is not a detail, and a risk that has not fired yet is still a risk |
| 3 | What the reader must do next, including a decision you need from them | A compressed report that hides the ask is a failed report |
| 4 | The concrete values those three depend on: numbers, file paths, commands, URLs | These are the payload; prose about them is not |

Fit them by **folding**, not by spending. A whole sentence that says "there was
also a warning" wastes the budget the warning needed. Attach it to the sentence
that carries the outcome:

> Capped the call at 5 seconds in `scripts/logic-post-commit.sh:12`, so a
> commit now always succeeds — but a memory written while the backend is down
> is dropped with only a stderr warning.

One sentence. Outcome, path, and the caveat that costs the reader data.

Row 1 covers any failure the response reports, not only your own: a diagnosis
of the reader's broken command is as protected as an admission that your own
edit did not work.

Rows 2 and 3 are the easiest to lose, because a source normally wraps both in
uncertainty — "production probably has the same rows", "I don't know whether
those rows matter, that's your call". **Uncertainty wrapped around a risk or a
decision is not hedging.** Cut the hedge and keep what it was carrying: "the
same failure is waiting in production", "whether to backfill or delete those
rows is your call".

**When items 1–3 cannot fit, the floor wins and the cap bends by exactly one
sentence.** This is the only licence to break rule 3, and it is available to
those three rows only. It is one sentence per response, not one per unmet item
— if an error and a destructive warning both overflow, they share it.

**Item 4 never bends the cap.** Concrete values are usually plentiful and
compete with each other, so rank them by what the reader cannot act without:
the path they must open, the command they must run, the number that decides
whether this is urgent. A value that merely evidences a claim — a measurement
supporting a diagnosis they have already accepted — is ordinary detail, and
loses to any of the first three rows. When values will not all fit, keep the
actionable ones and point at the rest.

## Counting

- **Sentences** are terminal-punctuated units, but the period is not the real
  limit — see the clause bound below.
- **`paragraph`** means one paragraph: three to five sentences, no blank line
  inside it.
- **Lists and headers never appear**, at any cap. The output is prose. What is
  banned is the *formatting*: a bullet is a free line that never has to pay a
  sentence, which is how a list escapes the cap. A series written inside a
  sentence — "revert, confirm the table is gone, backfill, then re-run" — pays
  its sentence like any other clause and is fine. Parallel steps of one action
  count as one claim under the clause bound; four unrelated assertions strung
  together with commas do not, whatever the punctuation suggests.
- **A code block kept under rule 5 counts zero**, at every cap including one
  sentence. At most one, and only when the block *is* the answer — a command to
  run, a snippet to paste. A block that merely illustrates is cut like any
  other detail. If the source has several and none is the answer, keep none.
- **Inline code spans are ordinary prose.** Rule 5's allowance is for fenced
  blocks; `` `a/path.ts` `` in a sentence is just a word in that sentence.
- **A sticky-cap acknowledgment counts zero** — see `sticky.md`.

### The clause bound

The period is not the limit; the **claim** is. A sentence makes one claim and
may carry whatever that claim needs — its cause, its cost, its caveat. It may
not carry a second, independent finding.

Punctuation is not the test. `and`, `but`, and `so` join clauses exactly as a
semicolon does, and a comma splice smuggles as well as an em dash. Judge the
content instead:

> The timeout fixes the hang, but it drops the memory, and there is no retry
> queue.

One claim — the fix and what it costs — however many clauses it took.

> The timeout fixes the hang, and the token package has drifted from the CSS.

Two findings welded together, and therefore two sentences no matter how it is
punctuated. Under a one-sentence cap the second is cut or pointed at.

Blunt backstop: past roughly forty-five words it is smuggling regardless.

This matters more than it looks. Without it "one sentence" means nothing, every
cap is satisfiable by anyone willing to write badly, and the bend becomes
decoration nobody needs to invoke. A response that obeys the letter of the cap
and reads like a run-on has failed it. When a thought will not fit, spend a
sentence you have, use the bend if the floor earns it, or point at the original.

## Cut order

Process narration first: what you searched, which files you opened, what you
ruled out along the way. Then roads not taken — the rejected alternative
matters to the person who chose it, not to the person reading the outcome.
Then hedging and caveats the outcome already implies — but check it against
rows 2 and 3 first, because uncertainty wrapped around a real risk or a real
decision is protected, not hedging. Then background.

Never cut the outcome, and never cut the fidelity floor.

## Worked examples

The source response, as it appeared on screen:

> I looked into why the post-commit hook was hanging, and the cause is that
> `bd` blocks on a Dolt handshake when the backend is unreachable.
>
> Walking through it: `scripts/logic-post-commit.sh` calls `bd remember`
> synchronously on every commit. That call opens a connection to the Dolt
> remote before it writes anything locally, and when the remote is down it
> retries with no ceiling — I measured 47 seconds on a cold network, and it
> never gives up at all if the socket stays open but idle.
>
> I checked the three other hooks in the repo and none share the pattern; this
> is the only synchronous `bd` call in a git hook.
>
> There were two ways to fix it. The narrow fix is to wrap the call in
> `timeout 5s`, so a wedged backend costs five seconds instead of the commit.
> The broader fix is to make `bd remember` write locally first and sync in the
> background, which is a change inside `bd` itself and out of scope here.
>
> I went with the narrow fix, in `scripts/logic-post-commit.sh:12`. The hook
> now caps the call at 5 seconds; if it times out the commit still succeeds and
> the memory is dropped with a warning on stderr.
>
> Heads up: dropping the memory is silent in the log file — you only see it in
> the terminal. If you commit while the backend is down, that decision note is
> gone, and there is no retry queue.

### `/less 1`

> Commits were hanging because the post-commit hook called `bd remember`
> synchronously and it retried an unreachable Dolt remote for 47 seconds or
> forever; a 5-second cap in `scripts/logic-post-commit.sh:12` fixes it, at the
> cost of silently dropping any memory written while the backend is down.

Kept: the failure, the cause, the measured number, the path, and the data-loss
caveat. Cut: the survey of other hooks (narration), the rejected in-`bd` fix
(road not taken), and the handshake mechanism (background). The caveat rides on
the same sentence as the fix rather than claiming one of its own.

### `/less 2`

> Commits were hanging because `scripts/logic-post-commit.sh` called
> `bd remember` synchronously, and that call retries an unreachable Dolt remote
> for 47 seconds — or indefinitely, if the socket stays open but idle. A
> 5-second timeout at line 12 means the commit now always succeeds, but a
> memory written while the backend is down is dropped with a warning on stderr
> only, and there is no retry queue.

The second sentence buys precision the one-sentence version had to blur: the
indefinite-hang case, and the absence of a retry queue.

### `/less paragraph`

> Commits were hanging because `scripts/logic-post-commit.sh` calls
> `bd remember` synchronously, and that call opens a Dolt connection before
> writing anything locally — when the remote is unreachable it retries for 47
> seconds, or forever if the socket stays open but idle. No other hook in the
> repo does this. I fixed it narrowly, with a 5-second timeout at line 12, so a
> wedged backend costs five seconds instead of the commit. The broader fix —
> having `bd remember` write locally and sync in the background — lives inside
> `bd` and was out of scope. Watch out for the trade: a memory written while
> the backend is down is dropped with only a stderr warning and no retry queue,
> so a decision note committed during an outage is simply gone.

At paragraph length the rejected alternative earns its place, because the
reader can now see the fix was a choice rather than the only option.

### When the payload is a command

A second source, abridged — a diagnosis, the command that fixes it, and a
warning against the cleanup the docs recommend:

> …your token expired on the 2nd, and `scripts/deploy.mjs:44` swallows the 401
> and reports it as "config unavailable", which is why you were looking at the
> build. Mint a fresh one with `doppler login && doppler configure set token
> …`. One caution: do not run `doppler configs tokens revoke --all` to clean up
> the old token, as the docs suggest — the CI token lives in the same config,
> so that breaks staging deploys for everyone until someone re-mints it.

At `/less 1`:

> Your staging deploys fail because your Doppler token expired on the 2nd and
> `scripts/deploy.mjs:44` reports the 401 as "config unavailable":
>
> ```bash
> doppler login && doppler configure set token …
> ```
>
> Do not clean up with `doppler configs tokens revoke --all` — it revokes the
> CI token too and breaks staging for everyone.

Both allowances are in play at once, which is legal and worth seeing. The block
is free under rule 5, because it *is* the answer. The destructive-action
warning is row 2 of the floor, it cannot fold into a sentence already carrying
the diagnosis, so it takes the one-sentence bend. The result is two sentences
under a one-sentence cap, and it is correct: the alternative is a reader who
runs the command the docs recommend and takes staging down.

### When the failure is still open

The hardest shape, because every row of the floor is live at once: something
broke, it is not fixed, the reader has a procedure to run, a decision only they
can make is outstanding, and the same failure is waiting somewhere else.
Abridged:

> The staging migration failed partway through and staging is half-migrated…
> `0042` created and backfilled `account_tenants`, then failed adding the
> `NOT NULL` constraint because 1,847 rows predate tenancy… Nothing is lost and
> production is untouched. To recover: revert to 0041, confirm the table is
> gone, backfill the orphan rows, then re-run 0042… I don't know whether those
> 1,847 rows matter — if staging data is disposable, deleting them is faster,
> but that is your call and I did not want to delete anything. Production
> almost certainly has the same pre-tenancy rows, so the same failure is
> waiting there.

At `/less 1`:

> Staging is half-migrated: `0042` failed on the `NOT NULL` constraint because
> 1,847 rows predate tenancy, and recovery is the four steps above, one of
> which needs your call on whether to backfill those rows or just delete them.
> Production almost certainly holds the same rows, so the same failure is
> waiting there.

The base sentence carries row 1 (the failure), row 3 (the procedure and the
decision), and the values those depend on. The procedure is pointed at rather
than prosed, because four steps will not fit beside a diagnosis without
breaking the clause bound. The latent production risk is row 2, it will not
fold into a sentence already doing that much, and so it takes the bend — spent
once, on the thing that costs most if the reader never learns it.

Note what the hedge became. "I don't know whether those rows matter… that is
your call" is uncertainty wrapped around a decision, so it survives as the
decision itself: *needs your call on whether to backfill those rows or just
delete them*.

## Degenerate sources

`SKILL.md`'s edge cases cover the empty and already-short sources; these are
the shapes beyond them:

| The source is | Do |
| --- | --- |
| Only a code block | Return the block plus at most one sentence |
| A question to the reader | Compress the question. Never answer it on their behalf |
| A report that ends by asking for a decision | The ask is row 3 of the floor — keep it, and still never decide on their behalf |
| A procedure whose steps are the payload | Prose the steps if they fit ("run X, then Y"). If they do not, name how many there are and point up at them |
| Several unrelated findings | Lead with the most consequential and point at the rest ("plus three smaller issues above") |
