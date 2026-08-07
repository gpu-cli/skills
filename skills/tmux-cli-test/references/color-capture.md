# Color Capture and Screenshots

The single source of truth for getting true color out of a tmux pane and
turning a frame into a PNG. `tui-review` and any other skill that needs color
fidelity reads this file rather than restating it.

## Enable true color before launching anything

Ratatui and crossterm TUIs paint with RGB (`Color::Rgb(r,g,b)`). tmux does not
preserve RGB in its cell storage unless the `Tc` capability is on, so
`capture-pane -e` strips every escape code and the TUI looks monochrome in
captures even though it renders in color in a real terminal.

Run this **once per tmux server, before starting the session**:

```bash
tmux set-option -g default-terminal "xterm-256color"
tmux set-option -ga terminal-overrides ",*:Tc"
```

Launch with `COLORTERM=truecolor` in the command so crossterm detects color
support:

```bash
tmux new-session -d -s "$SESSION" -x "$TMUX_TEST_WIDTH" -y "$TMUX_TEST_HEIGHT" \
  "COLORTERM=truecolor <command>"
```

Verify the override took effect:

```bash
tmux capture-pane -t "$SESSION" -e -p | hexdump -C | grep '1b 5b 33 38 3b 32'
# Expect |.[38;2;R;G;Bm| sequences (RGB foreground). Empty means Tc is not working.
```

## Color screenshots

`tmux_screenshot` from `scripts/tmux_helpers.sh` renders with `freeze
--language bash`, which does not preserve ANSI attributes. For any ratatui,
crossterm, or similar TUI, use `--language ansi` instead:

```bash
take_color_screenshot() {
  local session="$1" label="$2"
  local outfile="$TMUX_SCREENSHOT_DIR/${label}.png"
  tmux capture-pane -t "$session" -e -p | \
    freeze --language ansi --output "$outfile" &
  local pid=$!
  sleep 6          # freeze can hang; bound it rather than waiting forever
  kill $pid 2>/dev/null
  echo "$outfile"
}
```

Requires `freeze` (`brew install charmbracelet/tap/freeze`). Set
`TMUX_SCREENSHOT_DIR` and `mkdir -p` it first.

**After taking a screenshot, open the PNG with the Read tool.** A capture
nobody looks at proves nothing.

## Resize captures

```bash
for size in "80x24" "120x30" "160x40" "200x50"; do
  IFS='x' read -r w h <<< "$size"
  tmux resize-window -t "$SESSION" -x "$w" -y "$h"
  sleep 0.5
  take_color_screenshot "$SESSION" "resize-${size}"
done
```

`tmux_screenshot_sizes` sweeps the same four sizes and restores the original
geometry, but inherits the `--language bash` limitation above.

## Color assertions

Programmatic checks to run alongside visual review:

| Assertion | Checks |
|---|---|
| `tmux_assert_not_monochrome <session> [label]` | The pane emits at least one non-reset SGR code |
| `tmux_assert_min_colors <session> <n> [label]` | At least `n` distinct SGR sequences — a proxy for visual hierarchy |
| `tmux_assert_has_color <session> <code> [label]` | A specific ANSI code is present anywhere |
| `tmux_assert_text_color <session> <text> <code> [label]` | A line containing `<text>` also carries `<code>` |

```bash
tmux_assert_not_monochrome "$SESSION" "TUI uses color"
tmux_assert_min_colors "$SESSION" 4 "sufficient color variety"
tmux_assert_text_color "$SESSION" "READY" "32" "READY is green"
tmux_assert_text_color "$SESSION" "ERROR" "31" "ERROR is red"
```
