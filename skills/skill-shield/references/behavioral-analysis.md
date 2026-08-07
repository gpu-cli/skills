# Phase 3 — Behavioral Analysis

Pattern matching catches known-dangerous constructs. This phase catches packages
where every individual line is defensible but the whole is not. Run all six
probes; each one that fires becomes a finding under the check ID it maps to.

## 1. Scope proportionality

Compare declared capability against stated purpose. A "generate social posts"
skill has no reason to read `~/.aws/credentials`, and a formatter has no reason
to open a socket.

Ask what the skill would still do correctly if the suspicious capability were
removed. If the answer is "everything", the capability is unjustified.

## 2. Data flow

Trace each input — arguments, read files, environment variables, fetched
content — through to every sink: disk, stdout, network, another process.

Flag **asymmetric flows**: data that enters from a sensitive source and leaves
through a channel the user cannot see. Secrets reaching stdout are visible;
secrets reaching a URL are not.

## 3. Privilege inventory

Build three lists and compare them:

| List | Source |
|---|---|
| Requested | declared permissions, frontmatter, documented requirements |
| Used | what the scripts and instructions actually exercise |
| Needed | what the stated purpose genuinely requires |

Requested-but-unused is a latent risk and at minimum an INFO finding. Used-but-
undeclared is worse — the user consented to something narrower than what runs.

## 4. Temporal and state-dependent logic

Look for behavior gated on time, invocation count, or accumulated state: date
comparisons, "first run" branches, counters persisted between runs, checks
against a lockfile or marker file.

A skill that behaves differently on its tenth run than its first is a skill
whose audit does not generalize.

## 5. Self-modification

Does the package rewrite its own files while running — appending to its
`SKILL.md`, regenerating a bundled script, mutating its own config?

Self-modification defeats the integrity guarantee: the hashes recorded in Phase 1
describe a package that no longer exists after first use.

## 6. Anti-analysis behavior

Look for conditionals on `CI`, `TERM`, `TTY`, debugger presence, sandbox
hostnames, or known analysis paths. Any branch that makes the skill quieter or
more conservative under inspection is evidence of intent and escalates severity
rather than reducing it.

Absence of output is not absence of behavior — check what the other branch does.
