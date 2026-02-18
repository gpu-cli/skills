# Claude Code TUI Analysis

## Overview

- **Purpose**: AI-powered CLI coding assistant that understands codebases, makes edits with permission, and executes commands
- **Technology Stack**: Node.js/TypeScript, Ink (React for CLI), custom terminal rendering
- **Target Users**: Developers who want AI-assisted coding in their terminal
- **Version Analyzed**: v2.1.29

## Architecture

### Main Views/Screens

1. **Trust Dialog** (first-run security check)
2. **Welcome Screen** (main entry point with tips)
3. **Conversation View** (primary interaction area)
4. **Command Palette** (slash commands autocomplete)
5. **Tool Permission Dialogs** (approve/deny tool usage)
6. **Plan Mode** (structured planning workflow)
7. **Context Visualization** (token usage grid)
8. **Settings/Config Overlays** (theme, permissions, output style)
9. **Help System** (multi-tab help browser)

### Navigation Model

- **Modal dialogs** for confirmations and selections
- **Overlays** for help, settings, and visualizations
- **Inline completion** for commands (@, /, !)
- **Stateful modes** (plan mode, bash mode, auto-accept mode)

### State Management

- Conversation history with scrolling
- Tool execution state (pending, running, completed, error)
- Mode toggles (plan mode, auto-accept edits, verbose output)
- Context window tracking with token counts

---

## Screen Catalog

### 1. Trust Dialog

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ Accessing workspace:                                                           │
│                                                                                │
│ /path/to/directory                                                             │
│                                                                                │
│ Quick safety check: Is this a project you created or one you trust?           │
│ (Like your own code, a well-known open source project, or work from           │
│ your team). If not, take a moment to review what's in this folder first.      │
│                                                                                │
│ Claude Code'll be able to read, edit, and execute files here.                  │
│                                                                                │
│ Security guide                                                                 │
│                                                                                │
│ ❯ 1. Yes, I trust this folder                                                 │
│   2. No, exit                                                                  │
│                                                                                │
│ Enter to confirm · Esc to cancel                                               │
└────────────────────────────────────────────────────────────────────────────────┘
```

- **Purpose**: First-run security confirmation
- **Entry points**: First time opening claude in a new directory
- **Components**: Warning text, selection list, keyboard hints
- **Interactive elements**: Up/down navigation, Enter to confirm, Esc to cancel

### 2. Welcome Screen

```
╭─── Claude Code v2.1.29 ──────────────────────────────────────────────────────────╮
│                                              │ Tips for getting started           │
│                Welcome back James !          │ Ask Claude to create a new app...  │
│                                              │ ────────────────────────────────── │
│                                              │ Recent activity                    │
│                    ▐▛███▜▌                   │ No recent activity                 │
│                   ▝▜█████▛▘                  │                                    │
│                     ▘▘ ▝▝                    │                                    │
│      Opus 4.5 · Claude Max · James Lal       │                                    │
│ /path/to/workspace                           │                                    │
╰──────────────────────────────────────────────────────────────────────────────────╯
```

- **Purpose**: Landing screen showing user info and tips
- **Layout**: Two-column with ASCII art logo
- **Components**:
  - Logo (ASCII art)
  - User greeting
  - Model/subscription info
  - Current directory
  - Tips panel
  - Recent activity panel

### 3. Input Area

```
────────────────────────────────────────────────────────────────────────────────────
❯ Try "create a util logging.py that..."
────────────────────────────────────────────────────────────────────────────────────
  ? for shortcuts                                               ◯ /ide for VS Code
```

- **Purpose**: Primary text input for prompts
- **Components**:
  - Prompt indicator (`❯`)
  - Placeholder text (faded suggestions)
  - Left status hint (`? for shortcuts`)
  - Right status indicator (IDE connection)
- **States**:
  - Normal input: `❯ `
  - Bash mode: `! `
  - File path completion: `❯ @`
  - Command completion: `❯ /`

### 4. Keyboard Shortcuts Overlay

```
────────────────────────────────────────────────────────────────────────────────────
  ! for bash mode         double tap esc to clear input      ctrl + shift + - to undo
  / for commands          shift + tab to auto-accept edits   ctrl + z to suspend
  @ for file paths        ctrl + o for verbose output        ctrl + v to paste images
  & for background        ctrl + t to show todos             meta + p to switch model
                          \⏎ for newline                     ctrl + s to stash prompt
                                                             ctrl + g to edit in $EDITOR
                                                             /keybindings to customize
```

- **Purpose**: Quick reference for keyboard shortcuts
- **Entry points**: Press `?` when input is empty
- **Layout**: Three-column grid of shortcuts

### 5. Command Palette (Autocomplete)

```
────────────────────────────────────────────────────────────────────────────────────
❯ /
────────────────────────────────────────────────────────────────────────────────────
  /find-skills        Helps users discover and install agent skills...
  /frontend-design    Create distinctive, production-grade frontend...
  /skill-creator      Guide for creating effective skills...
  /add-dir            Add a new working directory
  /agents             Manage agent configurations
  /chrome             Claude in Chrome (Beta) settings
```

- **Purpose**: Browse and select slash commands
- **Entry points**: Type `/` in input
- **Components**:
  - Filtered command list
  - Command descriptions (truncated)
  - Selection highlight
- **Interactive elements**: Up/down navigation, Enter to select, Esc to cancel

### 6. Tool Execution Display

```
⏺ Write(hello.py)
  ⎿  Wrote 2 lines to hello.py
      1 print("Hello, World!")

⏺ Bash(python hello.py)
  ⎿  Error: Exit code 127
     (eval):1: command not found: python

⏺ Bash(python3 hello.py)
  ⎿  Hello, World!
```

- **Purpose**: Show tool invocations and their results
- **Components**:
  - Tool name with icon (`⏺`)
  - Result indicator (`⎿`)
  - Collapsible content
  - Line numbers for file content
  - Error highlighting

### 7. Tool Permission Dialog

```
────────────────────────────────────────────────────────────────────────────────────
 Bash command

   python hello.py
   Verify hello.py works

 Do you want to proceed?
 ❯ 1. Yes
   2. Yes, and don't ask again for python commands in /path
   3. No

 Esc to cancel · Tab to amend · ctrl+e to explain
```

- **Purpose**: Request permission before executing tools
- **Components**:
  - Tool type header
  - Command preview
  - Description/rationale
  - Permission options
  - Keyboard hints
- **Interactive elements**: 1/2/3 quick keys, up/down, Tab to amend

### 8. Diff View (File Edits)

```
⏺ Update(hello.py)
  ⎿  Added 1 line, removed 1 line
      1 -print("Hello, World!")
      1 +print("Hello Claude!")
```

- **Purpose**: Show file modifications
- **Components**:
  - Change summary (lines added/removed)
  - Line numbers
  - Removed lines (red with `-`)
  - Added lines (green with `+`)

### 9. Plan Mode Approval

```
────────────────────────────────────────────────────────────────────────────────────
 Ready to code?

 Here is Claude's plan:
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 Plan: Create hello.py

 Task
 Create a simple hello.py file in the current directory.

 Implementation
 Create /path/hello.py with a basic "Hello, World!" program.

 print("Hello, World!")

 Verification
 Run python hello.py to verify it outputs "Hello, World!"
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌

 ❯ 1. Yes, clear context and auto-accept edits (shift+tab)
   2. Yes, auto-accept edits
   3. Yes, manually approve edits
   4. Type here to tell Claude what to change

 ctrl-g to edit in VS Code · ~/.claude/plans/name.md
```

- **Purpose**: Review and approve AI-generated plans
- **Components**:
  - Plan title and sections
  - Markdown rendering with code blocks
  - Approval options
  - Editor shortcut
  - Plan file path

### 10. Context Visualization

```
     ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   Estimated usage by category
     ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛁ System prompt: 2.4k tokens (1.2%)
     ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛁ System tools: 15.9k tokens (8.0%)
     ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛁ Memory files: 124 tokens (0.1%)
     ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛁ Skills: 760 tokens (0.4%)
     ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶ ⛶   ⛁ Messages: 106 tokens (0.1%)
     ⛶ ⛶ ⛶ ⛝ ⛝ ⛝ ⛝ ⛝ ⛝ ⛝   ⛶ Free space: 148k (73.8%)
     ⛝ ⛝ ⛝ ⛝ ⛝ ⛝ ⛝ ⛝ ⛝ ⛝   ⛝ Autocompact buffer: 33.0k tokens (16.5%)

     Memory files · /memory
     └ ~/.claude/CLAUDE.md: 124 tokens

     Skills · /skills
     User
     └ find-skills: 79 tokens
     └ skill-creator: 60 tokens

     Plugin
     └ gpu-ml-trainer: 71 tokens
     └ frontend-design: 67 tokens
```

- **Purpose**: Visualize context window usage
- **Entry points**: `/context` command
- **Components**:
  - 10x8 grid with Unicode blocks
  - Category breakdown with token counts
  - File tree with memory files and skills

### 11. Theme Selector

```
────────────────────────────────────────────────────────────────────────────────────
 Theme

 Choose the text style that looks best with your terminal

 ❯ 1. Dark mode ✔
   2. Light mode
   3. Dark mode (colorblind-friendly)
   4. Light mode (colorblind-friendly)
   5. Dark mode (ANSI colors only)
   6. Light mode (ANSI colors only)

╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 1  function greet() {
 2 -  console.log("Hello, World!");
 2 +  console.log("Hello, Claude!");
 3  }
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 Syntax theme: Monokai Extended (ctrl+t to disable)

 Enter to select · Esc to cancel
```

- **Purpose**: Preview and select color themes
- **Components**:
  - Theme options list with checkmark
  - Live code preview with syntax highlighting
  - Diff preview (red/green)
  - Syntax theme name

### 12. Permissions Manager

```
──────────────────────────────────────────────────────────────────────────────────
 Permissions:  Allow   Ask   Deny   Workspace  (←/→ or tab to cycle)

 Claude Code won't ask before using allowed tools.
 ╭───────────────────────────────────────────────────────────────────────────────╮
 │ ⌕ Search…                                                                     │
 ╰───────────────────────────────────────────────────────────────────────────────╯

 ❯ 1. Add a new rule…

 Press ↑↓ to navigate · Enter to select · Type to search · Esc to cancel
```

- **Purpose**: Manage tool permission rules
- **Components**:
  - Tab bar for permission categories
  - Search input
  - Rules list
  - Keyboard hints

### 13. Output Style Selector

```
────────────────────────────────────────────────────────────────────────────────────
 Preferred output style

 This changes how Claude Code communicates with you

 ❯ 1. Default ✔      Claude completes coding tasks efficiently...
   2. Explanatory    Claude explains its implementation choices...
   3. Learning       Claude pauses and asks you to write small pieces...

 Enter to confirm · Esc to cancel
```

- **Purpose**: Choose AI response verbosity
- **Components**: Options with descriptions, checkmark on current

### 14. Memory Selector

```
╭────────────────────────────────────────────────────────────────────────────────╮
│                                                                                │
│ Select memory to edit:                                                         │
│                                                                                │
│  ❯ 1. User memory     Saved in ~/.claude/CLAUDE.md                             │
│    2. Project memory  Saved in ./CLAUDE.md                                     │
│                                                                                │
╰────────────────────────────────────────────────────────────────────────────────╯
```

- **Purpose**: Choose between user and project memory files
- **Entry points**: `/memory` command

### 15. Background Tasks Panel

```
╭────────────────────────────────────────────────────────────────────────────────╮
│ Background tasks                                                               │
│ No tasks currently running                                                     │
╰────────────────────────────────────────────────────────────────────────────────╯
  ↑/↓ to select · Enter to view · Esc to close
```

- **Purpose**: Monitor background/async tasks
- **Entry points**: `/tasks` command

### 16. Rewind Panel

```
────────────────────────────────────────────────────────────────────────────────────
 Rewind

 Restore the code and/or conversation to the point before…

   /clear
   No code changes

   /context
   No code changes

   /todos
   No code changes

   ! ls -la
   No code changes

   @/model
   No code changes

 ❯ (current)

 Enter to continue · Esc to exit
```

- **Purpose**: Undo/restore to previous conversation states
- **Entry points**: Meta+P (or similar shortcut)
- **Components**:
  - List of restore points
  - Code change indicators
  - Selection highlight

### 17. Doctor/Diagnostics

```
 Diagnostics
 └ Currently running: native (2.1.29)
 └ Path: /Users/jameslal/.local/share/claude/versions/2.1.29
 └ Invoked: /Users/jameslal/.local/share/claude/versions/2.1.29
 └ Config install method: native
 └ Search: OK (bundled)

 Updates
 └ Auto-updates: enabled
 └ Auto-update channel: latest
 └ Stable version: 2.1.17
 └ Latest version: 2.1.29

 Version Locks
 └ 2.1.17: PID 32310 (running)
 └ 2.1.7: PID 92421 (running)
 └ 2.1.29: PID 76106 (running)

 Press Enter to continue…
```

- **Purpose**: System diagnostics and version info
- **Entry points**: `/doctor` command
- **Components**: Tree-structured diagnostic info

### 18. Help Browser

```
──────────────────────────────────────────────────────────────────────────────────
 Claude Code v2.1.29  general   commands   custom-commands  (←/→ or tab to cycle)

 [Tab content varies by selection]

 For more help: https://code.claude.com/docs/en/overview
 Esc to cancel
```

- **Purpose**: Multi-tab help documentation
- **Entry points**: `/help` command
- **Tabs**:
  - `general`: Keyboard shortcuts overview
  - `commands`: Browse default slash commands
  - `custom-commands`: Browse user/plugin commands

### 19. Verbose Transcript Mode

```
──────────────────────────────────────────────────────────────── ctrl+e to show 44 previous messages ───
  ⎿  Wrote 2 lines to /path/hello.py
      1 print("Hello, World!")

⏺ Bash(python3 hello.py)
  ⎿  Hello, World!

⏺ Done. Created hello.py and verified it outputs "Hello, World!".     10:33 AM  claude-opus-4-5-20251101

∴ Thinking…

  The file was created and verified to work correctly.

────────────────────────────────────────────────────────────────────────────────────
  Showing detailed transcript · ctrl+o to toggle · ctrl+e to show all
```

- **Purpose**: Show full transcript with thinking and timestamps
- **Entry points**: Ctrl+O toggle
- **Components**:
  - Thinking indicator (`∴`)
  - Timestamps
  - Model name
  - Message count

---

## Keybindings

| Key | Context | Action |
|-----|---------|--------|
| `?` | Empty input | Show keyboard shortcuts |
| `!` | Start of input | Enter bash mode |
| `/` | Start of input | Open command palette |
| `@` | Input | File path completion |
| `&` | Start of input | Run in background |
| `Enter` | Input | Submit prompt |
| `Shift+Enter` or `\Enter` | Input | Insert newline |
| `Escape` | Any | Cancel/back/clear |
| `Escape Escape` | Input | Clear input |
| `Ctrl+O` | Any | Toggle verbose output |
| `Ctrl+T` | Any | Show todos |
| `Ctrl+V` | Input | Paste images |
| `Ctrl+S` | Input | Stash prompt |
| `Ctrl+G` | Input | Edit in $EDITOR |
| `Ctrl+Z` | Any | Suspend |
| `Ctrl+Shift+-` | Any | Undo |
| `Meta+P` | Any | Switch model / Rewind |
| `Shift+Tab` | Input | Toggle auto-accept edits |
| `Tab` | Dialog | Cycle options / Amend command |
| `Ctrl+E` | Permission dialog | Explain command |
| `↑/↓` or `j/k` | Lists | Navigate |
| `1/2/3/4` | Dialogs | Quick select option |

---

## Loading/Thinking States

Claude Code uses creative, varied loading indicators:

| State | Indicator |
|-------|-----------|
| Thinking | `✶ Boondoggling…`, `✢ Clauding… (thinking)`, `✻ Fermenting…`, `✳ Waddling… (thinking)`, `✽ Nesting… (thinking)`, `· Doing… (thinking)` |
| Running | `Running…` |

---

## Status Bar Modes

The bottom status bar shows current mode:

| Mode | Status |
|------|--------|
| Default | `? for shortcuts` |
| Plan mode | `⏸ plan mode on (shift+tab to cycle)` |
| Auto-accept edits | `⏵⏵ accept edits on (shift+tab to cycle)` |
| Interrupting | `esc to interrupt` |
| Verbose output | `Showing detailed transcript · ctrl+o to toggle · ctrl+e to show all` |

---

## Visual Patterns

### Icons and Symbols

| Symbol | Meaning |
|--------|---------|
| `❯` | Input prompt |
| `!` | Bash mode prompt |
| `⏺` | Tool execution |
| `⎿` | Tool result |
| `✔` | Current/selected |
| `∴` | Thinking |
| `⛶` | Free context block |
| `⛝` | Reserved/buffer block |
| `⛁` | Used context indicator |
| `▐▛███▜▌`, `▝▜█████▛▘` | Logo ASCII art |
| `└` | Tree branch |
| `❯` | Selected item |
| `●` | Indicator |

### Box Drawing

Uses Unicode box-drawing characters:
- `╭╮╰╯` for rounded corners
- `─│` for borders
- `╌` for dashed separators
- `├┤┬┴` for tree structures

### Color Scheme (Dark Mode)

- **Primary text**: White/light gray
- **Muted text**: Dark gray (placeholders, hints)
- **Success/additions**: Green
- **Errors/removals**: Red
- **Accents**: Cyan (selection, links)
- **Warnings**: Yellow
- **Code**: Syntax highlighted (Monokai)

---

## Component Inventory

### Input Components
- Text input with placeholder
- Command autocomplete dropdown
- File path autocomplete
- Multi-line input (with Shift+Enter)

### Display Components
- Scrollable conversation view
- Tool execution blocks (collapsible)
- Diff view (unified format)
- Code blocks with syntax highlighting
- Tree views (context, diagnostics)
- Grid visualization (context usage)

### Dialog Components
- Selection lists (numbered options)
- Confirmation dialogs
- Tab bars
- Search inputs
- Progress indicators

### Layout Components
- Split-pane (welcome screen)
- Bordered boxes
- Status bar (bottom)
- Header bar (title)

---

## Implementation Recommendations

### Recommended Tech Stack

1. **Rust + ratatui** - For high-performance TUI with full terminal control
2. **tokio** - Async runtime for non-blocking I/O
3. **crossterm** - Cross-platform terminal handling
4. **syntect** - Syntax highlighting

### Complexity Assessment

| Component | Complexity | Notes |
|-----------|------------|-------|
| Basic input/output | Medium | Multi-line, history, placeholders |
| Command autocomplete | Medium | Fuzzy matching, descriptions |
| Tool execution display | Medium | Collapsible, streaming output |
| Diff rendering | Medium | Line-level unified diffs |
| Context visualization | Low | Grid with token counting |
| Dialog system | Medium | Reusable modal framework |
| Theme support | Medium | Color scheme switching |
| Permission system | Medium | Rule-based, persistent |

### Potential Challenges

1. **Streaming output** - Tools emit output progressively; need async handling
2. **Multi-line input** - Shift+Enter detection varies by terminal
3. **Image paste** - Ctrl+V for images requires base64 handling
4. **Editor integration** - Launching $EDITOR and waiting for return
5. **Terminal resize** - Responsive layout recalculation
6. **Unicode handling** - Proper display width for CJK, emoji
7. **Undo/rewind** - Requires snapshotting conversation + file state

### Architecture Recommendations

1. **Component-based** - Reusable widgets for common patterns
2. **Event-driven** - Central event loop with async channels
3. **State machine** - For mode transitions (normal, plan, bash)
4. **Message store** - Scrollable conversation history
5. **Tool registry** - Pluggable tool execution framework
6. **Theme system** - Centralized color/style definitions

---

## Key Differentiators

1. **Creative loading states** - Varied, whimsical loading messages
2. **Plan mode workflow** - Structured planning before execution
3. **Auto-accept edits** - Trust mode for faster iteration
4. **Context visualization** - Unique grid-based token display
5. **Rewind feature** - Conversation + code state restoration
6. **Permission granularity** - Per-command, per-directory rules
7. **Inline completions** - @, /, ! trigger different modes
8. **Verbose toggle** - See AI thinking process
