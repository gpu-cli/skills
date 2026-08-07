# Test Patterns and Debugging

Worked examples for the tmux helpers. Read when you need a pattern beyond the
minimal start/wait/assert/kill loop.

## Full lifecycle with `tmux_test`

`tmux_test` starts the session, waits for the ready text, runs your function,
and kills the session even if an assertion fails.

```bash
test_help_page() {
    local s="$1"
    tmux_assert_contains "$s" "run" "help shows run command"
    tmux_assert_contains "$s" "dashboard" "help shows dashboard command"
    tmux_assert_not_contains "$s" "ERROR" "no errors in help"
}

tmux_test "help-test" "./crates/target/debug/gpu --help" "Usage:" test_help_page
```

## Testing a dashboard TUI

```bash
source .claude/skills/tmux-cli-test/scripts/tmux_helpers.sh
TMUX_TEST_WIDTH=140
TMUX_TEST_HEIGHT=35

GPU_BIN="./crates/target/debug/gpu"

tmux_start "dash" "$GPU_BIN dashboard"
tmux_wait_for "dash" "Pods" 15

tmux_assert_contains "dash" "Pods" "pods panel visible"
tmux_assert_contains "dash" "Jobs" "jobs panel visible"

# Navigate
tmux_send "dash" j
tmux_send "dash" j
tmux_wait_for "dash" "▶" 5              # selection cursor

# Switch panel
tmux_send "dash" Tab
tmux_wait_for_regex "dash" "Jobs.*selected" 5

# Open and close the help overlay
tmux_send "dash" '?'
tmux_wait_for "dash" "Help" 5
tmux_assert_contains "dash" "Keybindings" "help shows keybindings"
tmux_send "dash" Escape
tmux_wait_gone "dash" "Keybindings" 5

tmux_send "dash" q
tmux_wait_exit "dash" 5
```

## Testing an interactive prompt

```bash
tmux_start "init" "$GPU_BIN init"
tmux_wait_for "init" "project" 10

tmux_type "init" "my-test-project"
tmux_send "init" Enter

tmux_wait_for "init" "GPU" 10
tmux_send "init" j j Enter              # select with arrow keys
tmux_wait_for "init" "provider" 10

tmux_kill "init"
```

## Testing command output with branching states

```bash
tmux_start "status" "$GPU_BIN status"
tmux_wait_for_regex "status" "(No active|Pod)" 10

FRAME=$(tmux_capture "status")
if echo "$FRAME" | grep -q "No active"; then
    echo "No pods running - expected for cold test"
elif echo "$FRAME" | grep -q "Pod"; then
    tmux_assert_matches "status" "Pod.*READY\|ACTIVE" "pod in valid state"
fi

tmux_wait_exit "status" 15
```

## Testing error handling

```bash
tmux_start "bad-cmd" "$GPU_BIN run --nonexistent-flag"
tmux_wait_for_regex "bad-cmd" "error|Error|unknown" 10
tmux_assert_not_contains "bad-cmd" "panic" "no panics on bad input"
tmux_wait_exit "bad-cmd" 5
```

## Interrupting a long-running command

```bash
tmux_start "run-job" "$GPU_BIN run python -c 'import time; time.sleep(3600)'"
tmux_wait_for "run-job" "Running" 30

tmux_send "run-job" C-c
tmux_wait_for_regex "run-job" "cancel|interrupt|stopped" 10
tmux_wait_exit "run-job" 10
```

## Without the helpers

For a quick one-off check, drive tmux directly — but keep the polling loop
rather than sleeping.

```bash
tmux new-session -d -s test -x 120 -y 30 "./crates/target/debug/gpu dashboard"

for i in $(seq 1 100); do
    tmux capture-pane -t test -p | grep -q "Pods" && break
    sleep 0.3
done

FRAME=$(tmux capture-pane -t test -p)
echo "$FRAME" | grep -q "Pods" && echo "PASS" || echo "FAIL"

tmux send-keys -t test q
tmux kill-session -t test 2>/dev/null
```

## Debugging a failed test

```bash
tmux_capture "session-name"                                  # what is on screen now
tmux_capture_to_file "session-name" "/tmp/failed-frame.txt"  # save for comparison
tmux_capture_ansi "session-name"                             # include styling
```

## Session naming

Prefix session names so concurrent runs don't collide:

```text
gpu-test-dashboard
gpu-test-init
gpu-test-run-basic
gpu-test-status
gpu-test-error-handling
```
