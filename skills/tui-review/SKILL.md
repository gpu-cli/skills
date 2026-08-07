---
name: tui-review
description: "Runs a TUI in tmux, screenshots each state, and grades its UX. Use to review or critique a terminal UI."
---

# TUI Review

Critically review a terminal UI by running it live in tmux, screenshotting every
key state, and testing it against 10 UX dimensions. Benchmark against Claude
Code, OpenCode, and Codex — the three best-in-class AI terminal UIs.

**Gold standard**: every keypress produces visible change within 100ms; every
state has a designed appearance; color communicates meaning; no dead keys, no
blank screens, no stuck states.

## Process

1. Launch the TUI in tmux and take an **initial screenshot** — first impressions count.
2. Discover the UI: find help, navigation, and input areas.
3. Test each of the 10 dimensions, screenshotting every key state.
4. Take resize screenshots at 80x24, 120x30, 160x40, and 200x50.
5. **Open every screenshot with the Read tool.** This is what makes the review
   visual — you are looking at the rendered TUI and judging color, layout,
   contrast, and craft. A capture nobody views proves nothing.
6. Run the color assertions as an automated cross-check.
7. Write the graded report.

## Setup

Source the tmux helpers and set the capture directory:

```bash
source .claude/skills/tmux-cli-test/scripts/tmux_helpers.sh
TMUX_TEST_WIDTH=140
TMUX_TEST_HEIGHT=40
TMUX_TEST_POLL_INTERVAL=0.1
TMUX_SCREENSHOT_DIR="/tmp/tui-review-screenshots"
mkdir -p "$TMUX_SCREENSHOT_DIR"
```

**Before launching anything**, read
`.claude/skills/tmux-cli-test/references/color-capture.md` and follow it. It
covers the tmux true-color override that `capture-pane -e` needs, the
`take_color_screenshot` helper, resize sweeps, and the color assertions. Without
that override every screenshot comes out monochrome and the visual review is
worthless. (Adjust the path if the skills are installed under `.agents/skills/`.)

Read [references/report.md](references/report.md) for the screenshot plan, the
visual review checklist, and the report template.

## The 10 Dimensions

Read [references/heuristics.md](references/heuristics.md) for the test
procedure, pass/fail criteria, and best-in-class example behind each one.

1. **Responsiveness** — every keypress produces visible change within 100ms
2. **Input Mode Integrity** — trigger characters don't hijack mid-sentence text
3. **Visual Feedback** — every app state has a distinct visual indicator
4. **Navigation & Escape** — Escape always goes back; never get stuck
5. **Feedback Loops** — submit triggers clear, echo, loading, stream, completion
6. **Error & Empty States** — every state has a designed appearance, no blank screens
7. **Layout & Resize** — usable at 80x24, scales to 200x50+
8. **Keyboard Design** — all features keyboard-reachable, shortcuts discoverable
9. **Permission Flows** — destructive actions preview and require confirmation
10. **Visual Design & Color** — color carries meaning, adequate contrast,
    consistent palette, and borders that earn their place

## Grading

A = no issues. B = minor polish needed. C = noticeable UX friction. D = broken
workflows. F = unusable.

Facing an app you know nothing about? [references/report.md](references/report.md)
ends with a keypress order that surfaces the most in the fewest moves.
