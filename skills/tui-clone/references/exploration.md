# Exploration Recipes

Bash for driving the target TUI and appending findings as you go. Read when you
start exploring.

## Setup

```bash
source .claude/skills/tmux-cli-test/scripts/tmux_helpers.sh
TMUX_TEST_WIDTH=140
TMUX_TEST_HEIGHT=40

APP_NAME="lazygit"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p tui-analysis
OUTPUT_FILE="tui-analysis/${APP_NAME}-${TIMESTAMP}.md"
SESSION="analyze-${APP_NAME}"

cat > "$OUTPUT_FILE" << EOF
# $APP_NAME TUI Analysis

## Overview
- Purpose: [TODO]
- Technology stack: [TODO]
- Target users: [TODO]

## Screen Catalog
EOF

echo "Output file: $OUTPUT_FILE"
```

## Append-a-screen helper

Define this once, then call it every time you reach a new view. Writing on
discovery is what makes the run survive context compaction.

```bash
write_screen() {
    local name="$1" entry="$2" session="$3"
    {
        echo ""
        echo "### $name"
        echo "- Entry: $entry"
        echo '```'
        tmux_capture "$session"
        echo '```'
    } >> "$OUTPUT_FILE"
    echo "Wrote screen '$name' to $OUTPUT_FILE"
}
```

## Launch and capture the initial view

```bash
tmux_start "$SESSION" "$APP_NAME"
tmux_wait_for "$SESSION" "<ready-indicator>" 30
write_screen "Initial View" "Launch command" "$SESSION"
```

## Sweep the obvious entry points

```bash
# Help
tmux_send "$SESSION" "?"
if tmux_wait_for "$SESSION" "help\|Help\|Keybindings" 3; then
    write_screen "Help Screen" "Press ?" "$SESSION"
fi
tmux_send "$SESSION" Escape

# Numbered tabs or panels
for i in 1 2 3 4 5; do
    tmux_send "$SESSION" "$i"
    sleep 0.3
    write_screen "Panel $i" "Press $i" "$SESSION"
done
```

## Color palette

```bash
{
    echo ""
    echo "## Color Palette"
    echo ""
    echo '```ansi'
    tmux_capture_ansi "$SESSION"
    echo '```'
} >> "$OUTPUT_FILE"
```

For RGB-painting TUIs, enable the tmux true-color override first — see
`.claude/skills/tmux-cli-test/references/color-capture.md`. Without it the
capture comes back with no color information at all.

## Responsive behavior

```bash
for size in "80 24" "200 50"; do
    read -r w h <<< "$size"
    tmux resize-pane -t "$SESSION" -x "$w" -y "$h"
    sleep 0.5
    write_screen "Layout ${w}x${h}" "Resize" "$SESSION"
done
```

## Tables to append after exploring

```bash
{
    echo ""
    echo "## Keybindings"
    echo ""
    echo "| Key | Context | Action |"
    echo "|-----|---------|--------|"
    echo "| ? | Global | Show help |"
    echo "| q | Global | Quit |"
    echo "| j/k | List | Navigate up/down |"
    echo ""
    echo "## State Transitions"
    echo ""
    echo "| From | Trigger | To |"
    echo "|------|---------|-----|"
    echo "| Main | Enter on file | Diff view |"
    echo "| Main | c | Commit dialog |"
    echo "| Any | Escape | Previous view |"
} >> "$OUTPUT_FILE"
```

## Cleanup

```bash
tmux_send "$SESSION" q
tmux_wait_exit "$SESSION" 5
echo "Analysis complete: $OUTPUT_FILE"
```

## Known launch commands

| TUI | Launch | Ready text |
|-----|--------|------------|
| Claude Code | `claude` | `>` or prompt |
| OpenCode | `opencode` | Session or prompt |
| Codex | `codex` | Ready indicator |
| lazygit | `lazygit` | Status |
| lazydocker | `lazydocker` | Containers |
| htop | `htop` | CPU |
| btop | `btop` | CPU |
| k9s | `k9s` | Pods |
