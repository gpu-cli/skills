---
name: tmux-cli-test
description: "Drives a CLI or TUI in a tmux session — launches it, waits on conditions instead of sleeping, sends keys, and asserts on captured output. Use when asked to test, verify, or QA a terminal UI or CLI command flow."
---

# tmux CLI Testing

Test a CLI or TUI by running it in a tmux session: wait for a condition, send
input, assert on the captured frame, kill the session.

**Never sleep — always wait on a condition.** A `sleep` is a guess about timing;
it makes tests both slower and flakier than polling for the thing you actually
need.

## Helpers

```bash
source .claude/skills/tmux-cli-test/scripts/tmux_helpers.sh
```

| Function | Purpose |
|----------|---------|
| `tmux_start <session> <cmd>` | Launch command in a detached tmux session |
| `tmux_kill <session>` | Kill session |
| `tmux_is_alive <session>` | Check if session is running |
| `tmux_capture <session>` | Get pane text |
| `tmux_capture_ansi <session>` | Get pane text with ANSI codes |
| `tmux_capture_to_file <session> <path>` | Save pane text to a file |
| `tmux_wait_for <session> <text> [timeout]` | Poll until text appears |
| `tmux_wait_for_regex <session> <pattern> [timeout]` | Poll until regex matches |
| `tmux_wait_gone <session> <text> [timeout]` | Poll until text disappears |
| `tmux_wait_exit <session> [timeout]` | Poll until the process exits |
| `tmux_send <session> <keys...>` | Send keys (tmux key names) |
| `tmux_type <session> <text>` | Type literal text |
| `tmux_assert_contains <session> <text> [label]` | Assert text present |
| `tmux_assert_not_contains <session> <text> [label]` | Assert text absent |
| `tmux_assert_matches <session> <pattern> [label]` | Assert regex matches |
| `tmux_send_and_wait <session> <keys> <text> [timeout]` | Send then wait |
| `tmux_test <session> <cmd> <ready_text> <fn>` | Full lifecycle test |

Screenshot helpers (`tmux_screenshot`, `tmux_screenshot_sizes`) and color
assertions (`tmux_assert_not_monochrome`, `tmux_assert_min_colors`,
`tmux_assert_has_color`, `tmux_assert_text_color`) are documented in
[references/color-capture.md](references/color-capture.md), together with the
tmux true-color override that RGB-painting TUIs require.

Override the defaults before calling anything:

```bash
TMUX_TEST_POLL_INTERVAL=0.3  # seconds between polls
TMUX_TEST_TIMEOUT=30         # max wait seconds
TMUX_TEST_WIDTH=120          # terminal columns
TMUX_TEST_HEIGHT=30          # terminal rows
```

## Workflow

Every test is the same five steps: start the session, wait for a ready signal,
interact, assert on the captured output, kill the session.

```bash
source .claude/skills/tmux-cli-test/scripts/tmux_helpers.sh

tmux_start "test-help" "./crates/target/debug/gpu --help"
tmux_wait_for "test-help" "Usage:" 10
tmux_assert_contains "test-help" "run"
tmux_assert_contains "test-help" "dashboard"
tmux_kill "test-help"
```

Prefer `tmux_test` when a test has more than a couple of assertions — it kills
the session even when one fails.

## More Patterns

| Need | Read |
|---|---|
| Dashboards, interactive prompts, error paths, `C-c` interrupts, driving tmux without the helpers, debugging a failed test, session naming | [references/examples.md](references/examples.md) |
| Running the CLI inside a container | [references/docker.md](references/docker.md) |
| True color, screenshots, color assertions | [references/color-capture.md](references/color-capture.md) |

## Anti-Patterns

| Bad | Good | Why |
|-----|------|-----|
| `sleep 3` | `tmux_wait_for s "Ready"` | Sleeps are flaky and slow |
| `sleep 5 && tmux capture-pane` | `tmux_wait_for s "expected" && tmux_capture s` | Wait on a condition, not a duration |
| Hardcoded binary path | `GPU_BIN=./crates/target/debug/gpu` | Easy to switch debug/release |
| No cleanup on failure | `tmux_test` or an explicit `tmux_kill` | Leftover sessions break the next run |
| `grep -q` with no timeout loop | `tmux_wait_for` | The text may not be rendered yet |
| Checking `.len()` of TUI text | Check displayed content only | Unicode width is not byte length |
