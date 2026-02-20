#!/usr/bin/env bash
# asset_helpers.sh - Social media asset capture helpers for dev-post-generator.
# Source this file after sourcing tmux_helpers.sh.
#
# All functions:
# - Return output path on stdout (for capture by caller)
# - Skip gracefully if required tools (freeze, asciinema) are not installed
# - Follow set -euo pipefail conventions from tmux_helpers.sh

set -euo pipefail

# Source tmux_helpers.sh from the tmux-cli-test skill
ASSET_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMUX_HELPERS="${ASSET_SCRIPT_DIR}/../../tmux-cli-test/scripts/tmux_helpers.sh"
if [ -f "$TMUX_HELPERS" ]; then
    source "$TMUX_HELPERS"
fi

# Defaults (override before calling functions)
DEVPOST_ASSET_DIR="${DEVPOST_ASSET_DIR:-/tmp/devpost-assets}"
DEVPOST_SESSION="${DEVPOST_SESSION:-devpost-capture}"

# --- Tool checks ---

# Check if freeze is available. Returns 0 if yes, 1 if no (with message).
_check_freeze() {
    if ! command -v freeze &>/dev/null; then
        echo "SKIP: freeze not installed (brew install charmbracelet/tap/freeze)" >&2
        return 1
    fi
    return 0
}

# Check if asciinema is available. Returns 0 if yes, 1 if no (with message).
_check_asciinema() {
    if ! command -v asciinema &>/dev/null; then
        echo "SKIP: asciinema not installed (brew install asciinema)" >&2
        return 1
    fi
    return 0
}

# --- Capture functions ---

# Extract lines from a file and screenshot via freeze with syntax highlighting.
# Usage: capture_code_snippet <file> <start_line> <end_line> <language> <label>
# Returns: path to PNG file on stdout
# Example: capture_code_snippet src/main.rs 10 30 rust "new-parser"
capture_code_snippet() {
    local file="$1"
    local start="$2"
    local end="$3"
    local lang="$4"
    local label="$5"
    mkdir -p "$DEVPOST_ASSET_DIR"
    local outfile="${DEVPOST_ASSET_DIR}/${label}.png"

    if ! _check_freeze; then
        return 1
    fi

    if [ ! -f "$file" ]; then
        echo "SKIP: file not found: $file" >&2
        return 1
    fi

    sed -n "${start},${end}p" "$file" \
        | freeze --language "$lang" --window=false -o "$outfile" 2>/dev/null

    if [ -f "$outfile" ]; then
        echo "$outfile"
    else
        echo "FAIL: code snippet screenshot not created" >&2
        return 1
    fi
}

# Screenshot a git diff for a specific file between base branch and HEAD.
# Usage: capture_diff_screenshot <base_branch> <filepath> <label>
# Returns: path to PNG file on stdout
# Example: capture_diff_screenshot main src/parser.rs "parser-changes"
capture_diff_screenshot() {
    local base="$1"
    local filepath="$2"
    local label="$3"
    mkdir -p "$DEVPOST_ASSET_DIR"
    local outfile="${DEVPOST_ASSET_DIR}/${label}.png"

    if ! _check_freeze; then
        return 1
    fi

    local diff_output
    diff_output=$(git diff "${base}...HEAD" -- "$filepath" 2>/dev/null || true)

    if [ -z "$diff_output" ]; then
        echo "SKIP: no diff for $filepath against $base" >&2
        return 1
    fi

    echo "$diff_output" \
        | freeze --language diff --window=false -o "$outfile" 2>/dev/null

    if [ -f "$outfile" ]; then
        echo "$outfile"
    else
        echo "FAIL: diff screenshot not created" >&2
        return 1
    fi
}

# Launch a command in tmux, wait for ready text, optionally send keys, then screenshot.
# Usage: capture_terminal_app <cmd> <ready_text> <label> [keys...]
# Returns: path to PNG file on stdout
# Example: capture_terminal_app "./my-cli --help" "Usage:" "help-screen"
# Example: capture_terminal_app "./my-tui" "Ready" "dark-mode" "Tab" "Enter"
capture_terminal_app() {
    local cmd="$1"
    local ready_text="$2"
    local label="$3"
    shift 3
    local keys=("$@")
    mkdir -p "$DEVPOST_ASSET_DIR"
    local outfile="${DEVPOST_ASSET_DIR}/${label}.png"

    if ! _check_freeze; then
        return 1
    fi

    # Start session
    tmux_start "$DEVPOST_SESSION" "$cmd"

    # Wait for ready
    if ! tmux_wait_for "$DEVPOST_SESSION" "$ready_text" 15; then
        echo "SKIP: app never showed ready text: '$ready_text'" >&2
        tmux_kill "$DEVPOST_SESSION"
        return 1
    fi

    # Send additional keys if provided
    for key in "${keys[@]}"; do
        tmux_send "$DEVPOST_SESSION" "$key"
        sleep 0.3
    done

    # Give a moment for final render
    sleep 0.5

    # Capture screenshot
    tmux capture-pane -t "$DEVPOST_SESSION" -p -e \
        | freeze --language ansi --window=false -o "$outfile" 2>/dev/null

    tmux_kill "$DEVPOST_SESSION"

    if [ -f "$outfile" ]; then
        echo "$outfile"
    else
        echo "FAIL: terminal screenshot not created" >&2
        return 1
    fi
}

# Capture before/after screenshots by checking out the base branch and then returning.
# Usage: capture_before_after <base_branch> <cmd> <ready_text> <label>
# Returns: paths to both PNG files on stdout (one per line)
# Example: capture_before_after main "./my-tui" "Ready" "dark-mode"
capture_before_after() {
    local base="$1"
    local cmd="$2"
    local ready_text="$3"
    local label="$4"
    mkdir -p "$DEVPOST_ASSET_DIR"
    local before_file="${DEVPOST_ASSET_DIR}/${label}-before.png"
    local after_file="${DEVPOST_ASSET_DIR}/${label}-after.png"

    if ! _check_freeze; then
        return 1
    fi

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Stash any uncommitted changes
    local stashed=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        git stash push -m "devpost-before-after" 2>/dev/null
        stashed=true
    fi

    # Capture "before" on base branch
    git checkout "$base" 2>/dev/null
    if capture_terminal_app "$cmd" "$ready_text" "${label}-before"; then
        echo "$before_file"
    else
        echo "SKIP: could not capture 'before' state" >&2
    fi

    # Return to feature branch
    git checkout "$current_branch" 2>/dev/null
    if [ "$stashed" = true ]; then
        git stash pop 2>/dev/null || true
    fi

    # Capture "after" on current branch
    if capture_terminal_app "$cmd" "$ready_text" "${label}-after"; then
        echo "$after_file"
    else
        echo "SKIP: could not capture 'after' state" >&2
    fi
}

# Record a terminal session using asciinema.
# Usage: record_terminal <cmd> <label> [idle_time_limit]
# Returns: path to cast file on stdout
# Example: record_terminal "./my-cli demo" "demo-recording" 3
record_terminal() {
    local cmd="$1"
    local label="$2"
    local idle_limit="${3:-5}"
    mkdir -p "$DEVPOST_ASSET_DIR"
    local outfile="${DEVPOST_ASSET_DIR}/${label}.cast"

    if ! _check_asciinema; then
        return 1
    fi

    asciinema rec "$outfile" \
        --command "$cmd" \
        --idle-time-limit "$idle_limit" \
        --overwrite 2>/dev/null

    if [ -f "$outfile" ]; then
        echo "$outfile"
    else
        echo "FAIL: recording not created" >&2
        return 1
    fi
}

# Print recommended dimensions and framing guidance for manual screenshots.
# Usage: print_manual_screenshot_guide <platform>
# Example: print_manual_screenshot_guide twitter
print_manual_screenshot_guide() {
    local platform="$1"

    echo "=== Manual Screenshot Guide: $platform ==="
    echo ""

    case "$platform" in
        twitter|x)
            echo "Recommended dimensions: 1200x675px (16:9) or 1200x1200px (1:1)"
            echo "Max file size: 5MB (photos), 15MB (GIFs)"
            echo "Formats: PNG, JPEG, GIF, WebP"
            echo "Tips:"
            echo "  - Use high contrast — Twitter timeline has a white/dark background"
            echo "  - Text in images should be large enough to read on mobile"
            echo "  - Up to 4 images per tweet"
            ;;
        linkedin)
            echo "Recommended dimensions: 1200x627px (1.91:1) or 1080x1080px (1:1)"
            echo "Max file size: 10MB"
            echo "Formats: PNG, JPEG, GIF"
            echo "Tips:"
            echo "  - Professional look — clean backgrounds, readable fonts"
            echo "  - Single image posts perform better than carousels for dev content"
            echo "  - Include your project URL in the image if possible"
            ;;
        bluesky)
            echo "Recommended dimensions: 2000x1000px (2:1) or 1000x1000px (1:1)"
            echo "Max file size: 1MB"
            echo "Formats: PNG, JPEG"
            echo "Tips:"
            echo "  - Keep file size small — compress PNGs"
            echo "  - Up to 4 images per post"
            echo "  - Alt text is strongly encouraged by the community"
            ;;
        mastodon)
            echo "Recommended dimensions: 1920x1080px (16:9)"
            echo "Max file size: varies by instance (typically 8-16MB)"
            echo "Formats: PNG, JPEG, GIF, WebP"
            echo "Tips:"
            echo "  - Alt text is expected (community norm)"
            echo "  - Mark sensitive images with CW if appropriate"
            echo "  - Up to 4 media attachments"
            ;;
        reddit)
            echo "Recommended dimensions: 1200x628px minimum"
            echo "Max file size: 20MB"
            echo "Formats: PNG, JPEG, GIF"
            echo "Tips:"
            echo "  - Subreddit-specific — check rules for image posts"
            echo "  - GIFs and short videos get high engagement in dev subreddits"
            echo "  - Before/after comparisons do well"
            ;;
        *)
            echo "No specific guide for '$platform'."
            echo "General: 1200x675px, PNG or JPEG, under 5MB, high contrast."
            ;;
    esac
    echo ""
}

# Append an asset inventory table to the output README.
# Usage: write_asset_inventory <output_file>
# Scans DEVPOST_ASSET_DIR and writes a markdown table of all assets.
write_asset_inventory() {
    local output_file="$1"

    {
        echo ""
        echo "## Asset Inventory"
        echo ""
        echo "| File | Type | Size |"
        echo "|------|------|------|"
    } >> "$output_file"

    if [ -d "$DEVPOST_ASSET_DIR" ]; then
        for asset in "$DEVPOST_ASSET_DIR"/*; do
            [ -f "$asset" ] || continue
            local filename
            filename=$(basename "$asset")
            local ext="${filename##*.}"
            local size
            size=$(wc -c < "$asset" | tr -d ' ')

            local type="unknown"
            case "$ext" in
                png|jpg|jpeg) type="image" ;;
                gif) type="animated image" ;;
                cast) type="asciinema recording" ;;
                svg) type="vector image" ;;
                *) type="file" ;;
            esac

            # Human-readable size
            local human_size
            if [ "$size" -ge 1048576 ]; then
                human_size="$(echo "scale=1; $size / 1048576" | bc)MB"
            elif [ "$size" -ge 1024 ]; then
                human_size="$(echo "scale=1; $size / 1024" | bc)KB"
            else
                human_size="${size}B"
            fi

            echo "| \`$filename\` | $type | $human_size |" >> "$output_file"
        done
    fi

    if [ ! -d "$DEVPOST_ASSET_DIR" ] || [ -z "$(ls -A "$DEVPOST_ASSET_DIR" 2>/dev/null)" ]; then
        echo "| *(no assets captured)* | — | — |" >> "$output_file"
    fi
}
