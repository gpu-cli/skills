---
name: tui-clone
description: "Explores a TUI in tmux and documents every view, keybinding, and layout as a clone-ready spec. Use when asked to reverse-engineer, analyze, or document a terminal UI such as Claude Code, lazygit, or any ratatui app."
---

# TUI Clone

Explore a terminal UI systematically and produce documentation complete enough
to rebuild it.

**Write findings to the output file the moment you discover them.** Do not batch
them up in context and write at the end — a long exploration will be compacted
before it finishes, and anything still in context is lost.

## Output File

Write to `tui-analysis/<app-name>-<timestamp>.md` in the working directory. The
timestamp keeps concurrent sessions from clobbering each other.

**Never write output inside this skill's directory.** Skill directories ship to
every install, and an agent reading the package will mistake a past analysis for
instructions.

## Process

1. Create the output file with its header, then launch the target in tmux and
   capture the initial view.
2. Explore, appending each screen as you find it: help overlay, numbered tabs
   and panels, then every view reachable from them.
3. Capture the color palette with an ANSI capture.
4. Resize to 80x24 and 200x50 and capture each layout.
5. Append the keybinding and state-transition tables.
6. Finish with the implementation notes.

Read [references/exploration.md](references/exploration.md) for the setup, the
`write_screen` helper, the exploration sweeps, and the known launch commands and
ready-text for common TUIs. Read
[references/output-template.md](references/output-template.md) for the section
order, ASCII diagram conventions, and the completeness check.

## What to Capture

Beyond screens and keybindings, a spec needs:

- **State transitions** — what triggers each view change
- **Component inventory** — the reusable elements (lists, modals, tabs, status
  bar, progress, inputs) and where each appears
- **Color palette** — an ANSI capture for styling
- **Responsive behavior** — compact and wide layouts
- **Error and loading states** — try invalid operations; look for spinners,
  empty states, and confirmation dialogs
- **Data structures** — lists (single and multi-select), trees, tables,
  scrollable text views, diffs

## Resuming After Compaction

The output file is the state. Find it and read it, then keep appending:

```bash
ls -la tui-analysis/*.md
```

The timestamp in the filename identifies which session you are continuing.
