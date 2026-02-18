# Codex TUI Analysis

## Overview
- **Purpose**: AI-powered coding assistant CLI from OpenAI
- **Technology stack**: Rust + Ratatui (inferred from binary, TUI patterns)
- **Target users**: Developers who want AI assistance in terminal workflows

## Key Features (from --help)
- Interactive AI coding sessions
- Non-interactive exec mode (`codex exec`)
- Code review mode (`codex review`)
- MCP server integration (experimental)
- Session resume/fork capabilities
- Sandbox modes (read-only, workspace-write, full-access)
- Approval policies (untrusted, on-failure, on-request, never)
- Image attachment support
- Live web search integration

## Screen Catalog

### Initial Directory Warning Dialog
- **Entry**: Launch `codex` in non-git directory
- **Type**: Selection dialog with radio options
- **Behavior**: Warns user about non-version-controlled directory

```
> You are running Codex in /private/tmp

  Since this folder is not version controlled, we recommend requiring approval of all edits and commands.

  1. Allow Codex to work in this folder without asking for approval
› 2. Require approval of edits and commands

  Press enter to continue
```

**Components observed**:
- Warning message block
- Radio selection (numbered options)
- Selected indicator: `›`
- Instructional footer

### Main View (Home Screen)
- **Entry**: Launch `codex` or complete initial dialog
- **Type**: Input prompt with context banners

```
╭─────────────────────────────────────────────────╮
│ ✨ Update available! 0.93.0 -> 0.94.0           │
│ Run npm install -g @openai/codex to update.     │
│                                                 │
│ See full release notes:                         │
│ https://github.com/openai/codex/releases/latest │
╰─────────────────────────────────────────────────╯

╭───────────────────────────────────────────────────╮
│ >_ OpenAI Codex (v0.93.0)                         │
│                                                   │
│ model:     gpt-5.2-codex xhigh   /model to change │
│ directory: /private/tmp                           │
╰───────────────────────────────────────────────────╯

  To get started, describe a task or try one of these commands:

  /init - create an AGENTS.md file with instructions for Codex
  /status - show current session configuration
  /permissions - choose what Codex is allowed to do
  /model - choose what model and reasoning effort to use
  /review - review any changes and find issues

⚠ MCP client for `tauri-mcp` failed to start: [error message]

⚠ MCP startup incomplete (failed: tauri-mcp)


› Run /review on my current changes

  ? for shortcuts                                     100% context left
```

**Layout Breakdown**:
```
┌─────────────────────────────────────────────────────┐
│ Update Banner (optional, rounded border)            │
├─────────────────────────────────────────────────────┤
│ Header Box (app name, version, model, directory)    │
├─────────────────────────────────────────────────────┤
│ Getting Started Commands (hint text)                │
├─────────────────────────────────────────────────────┤
│ Warning Messages (⚠ prefixed)                       │
├─────────────────────────────────────────────────────┤
│ Input Prompt (› prefix, ghost text suggestion)      │
├─────────────────────────────────────────────────────┤
│ Status Bar (? for shortcuts | context indicator)    │
└─────────────────────────────────────────────────────┘
```

**Components observed**:
- Rounded border boxes (`╭╮╰╯│─`)
- Emoji usage (✨, ⚠)
- Ghost text input suggestion
- Context percentage indicator (100% context left)
- Keyboard shortcut hint (? for shortcuts)
- Inline help with slash commands

### Help/Shortcuts Overlay
- **Entry**: Press `?` from main view
- **Type**: Bottom-aligned overlay (replaces status bar)

```
  / for commands                             ! for shell commands
  ctrl + j for newline                       tab to queue message
  @ for file paths                           ctrl + v to paste images
  ctrl + g to edit in external editor        esc esc to edit previous message
  ctrl + c to exit
  ctrl + t to view transcript
```

**Layout**: Two-column shortcut table at bottom
**Behavior**: Replaces single-line status bar, same viewport shows content above

### Slash Command Menu
- **Entry**: Type `/` in input prompt
- **Type**: Bottom-aligned autocomplete dropdown

```
› /

  /model         choose what model and reasoning effort to use
  /permissions   choose what Codex is allowed to do
  /experimental  toggle experimental features
  /skills        use skills to improve how Codex performs specific tasks
  /review        review my current changes and find issues
  /rename        rename the current thread
  /new           start a new chat during a conversation
  /resume        resume a saved chat
```

**Components**:
- Fuzzy matching autocomplete
- Two-column layout: command name | description
- First item highlighted (selected)
- Scrollable list for many commands

**Available Commands**:
| Command | Description |
|---------|-------------|
| `/model` | Choose model and reasoning effort |
| `/permissions` | Choose what Codex is allowed to do |
| `/experimental` | Toggle experimental features |
| `/skills` | Use skills for specific tasks |
| `/review` | Review current changes and find issues |
| `/rename` | Rename the current thread |
| `/new` | Start a new chat during conversation |
| `/resume` | Resume a saved chat |
| `/init` | Create AGENTS.md file |
| `/status` | Show session configuration |

### Model Selection Dialog
- **Entry**: `/model` command
- **Type**: Multi-step selection dialog (model → reasoning)

**Step 1: Model Selection**
```
  Select Model and Effort
  Access legacy models by running codex -m <model_name> or in your config.toml

› 1. gpt-5.2-codex (current)  Latest frontier agentic coding model.
  2. gpt-5.2                  Latest frontier model with improvements across knowledge, reasoning and coding
  3. gpt-5.1-codex-max        Codex-optimized flagship for deep and fast reasoning.
  4. gpt-5.1-codex-mini       Optimized for codex. Cheaper, faster, but less capable.

  Press enter to select reasoning effort, or esc to dismiss.
```

**Step 2: Reasoning Level Selection**
```
  Select Reasoning Level for gpt-5.2-codex

  1. Low                   Fast responses with lighter reasoning
  2. Medium (default)      Balances speed and reasoning depth for everyday tasks
  3. High                  Greater reasoning depth for complex problems
› 4. Extra high (current)  Extra high reasoning depth for complex problems
                           ⚠ Extra high reasoning effort can quickly consume Plus plan rate limits.

  Press enter to confirm or esc to go back
```

**Components**:
- Numbered radio options
- Selection indicator: `›`
- (current) marker for active selection
- (default) marker for recommended option
- Warning annotation under items (⚠ prefix)
- Multi-line descriptions for complex options
- Breadcrumb navigation (esc to go back)

### AI Response/Working View
- **Entry**: Submit any prompt or command that triggers AI
- **Type**: Streaming response with tool use display

```
› /permissions/permissions


• I'm preparing to read the instructions file at /private/tmp/AGENTS.md using shell commands since the environment is read-only.

• Explored
  └ List ls

• Planning file read (11s • esc to interrupt)


› Run /review on my current changes

  ? for shortcuts                                     100% context left
```

**Layout Breakdown**:
```
┌─────────────────────────────────────────────────────┐
│ User message (prefixed with ›)                      │
├─────────────────────────────────────────────────────┤
│ Response blocks (• prefixed):                       │
│   - Thinking text (streaming)                       │
│   - Collapsible tool use tree:                      │
│     └ Tool Name  (expandable with action details)   │
├─────────────────────────────────────────────────────┤
│ Current status line:                                │
│ • Working (Xs • esc to interrupt)                   │
├─────────────────────────────────────────────────────┤
│ Input prompt (ghost text suggestion)                │
├─────────────────────────────────────────────────────┤
│ Status bar                                          │
└─────────────────────────────────────────────────────┘
```

**Components**:
- Bullet points (•) for response sections
- Tree indentation (└) for nested tool calls
- Elapsed time display (Xs format)
- Interrupt hint (esc to interrupt)
- Collapsible/expandable sections ("Explored")
- Context remaining indicator (93% context left)

### Interrupted State
- **Entry**: Press `Escape` during AI processing
- **Type**: Inline status update

```
■ Conversation interrupted - tell the model what to do differently. Something went wrong? Hit `/feedback` to report the issue.
```

**Components**:
- Solid square (■) stop indicator
- Instructional text with action hint
- `/feedback` command suggestion for issues

### Transcript View (Full Screen)
- **Entry**: Press `Ctrl+T` from main view
- **Type**: Full-screen scrollable text view

```
/ T R A N S C R I P T / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / / /
[Command output showing file listings, tool results, timing info]

• I'm checking if the AGENTS.md file exists in /private/tmp using a targeted file search...

$ rg --files -g 'AGENTS.md'
beads-explore/AGENTS.md
gastown-explore/AGENTS.md
[... more results ...]
✓ • 332ms

■ Conversation interrupted - tell the model what to do differently...
───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── 100% ─
 ↑/↓ to scroll   pgup/pgdn to page   home/end to jump
 q to quit   esc to edit prev
```

**Layout**:
```
┌─────────────────────────────────────────────────────┐
│ / T R A N S C R I P T / / / / / / (diagonal stripe) │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Scrollable content area:                            │
│   - Tool outputs with $ prefix for commands         │
│   - Timing info (✓ • 332ms)                         │
│   - AI thinking (• prefix)                          │
│   - Interrupt markers (■)                           │
│                                                     │
├─────────────────────────────────────────────────────┤
│ Progress bar (─────── 100% ─)                       │
├─────────────────────────────────────────────────────┤
│ Navigation hints (↑/↓ pgup/pgdn home/end q esc)     │
└─────────────────────────────────────────────────────┘
```

**Components**:
- Diagonal stripe header with title
- Scrollable transcript content
- Shell commands with `$` prefix
- Success checkmark (✓) with timing
- Scroll position indicator (100%)
- Bottom navigation hint bar

### Status Panel (/status)
- **Entry**: `/status` command
- **Type**: Inline information panel (boxed)

```
╭────────────────────────────────────────────────────────────────────────────╮
│  >_ OpenAI Codex (v0.93.0)                                                 │
│                                                                            │
│ Visit https://chatgpt.com/codex/settings/usage for up-to-date              │
│ information on rate limits and credits                                     │
│                                                                            │
│  Model:            gpt-5.2-codex (reasoning xhigh, summaries auto)         │
│  Directory:        /private/tmp                                            │
│  Approval:         on-request                                              │
│  Sandbox:          read-only                                               │
│  Agents.md:        <none>                                                  │
│  Account:          james@littlebearlabs.io (Pro)                           │
│  Session:          019c2493-1f7c-7b03-a6e8-8aaa6e80717c                    │
│                                                                            │
│  Context window:   93% left (29.9K used / 258K)                            │
│  5h limit:         [████████████████████] 100% left (resets 15:37)         │
│  Weekly limit:     [████████████████████] 99% left (resets 19:18 on 9 Feb) │
╰────────────────────────────────────────────────────────────────────────────╯
```

**Information displayed**:
- App name and version
- Usage documentation link
- Model with reasoning level and summary settings
- Working directory
- Approval policy mode
- Sandbox mode
- AGENTS.md file status
- Account info (email, plan tier)
- Session ID (UUID)
- Context window usage (percentage, tokens used/total)
- Rate limit bars with reset times (5h, weekly)

**Components**:
- Bordered info panel (rounded corners)
- Key-value pairs aligned
- Progress bars for rate limits (`[████████████████████]`)
- Reset time annotations

### Session Resume Picker (/resume)
- **Entry**: `/resume` command
- **Type**: Full-screen interactive list with search

```
Resume a previous session
Type to search
  Updated       Branch  Conversation
> 1 minute ago  -       /permissions/permissions


enter to resume     esc to start new     ctrl + c to quit     ↑/↓ to browse
```

**Layout**:
```
┌─────────────────────────────────────────────────────┐
│ Title: Resume a previous session                    │
│ Search hint: Type to search                         │
├─────────────────────────────────────────────────────┤
│ Column Headers: Updated | Branch | Conversation     │
├─────────────────────────────────────────────────────┤
│ > Selected row (highlighted)                        │
│   Other sessions...                                 │
│                                                     │
├─────────────────────────────────────────────────────┤
│ Action hints: enter/esc/ctrl+c/↑/↓                  │
└─────────────────────────────────────────────────────┘
```

**Components**:
- Full-screen selection interface
- Search-as-you-type filtering
- Table with columns (Updated, Branch, Conversation)
- Row selection indicator: `>`
- Bottom action hints bar

### File Path Autocomplete (@)
- **Entry**: Type `@` in input prompt
- **Type**: Dropdown autocomplete for file paths

```
› @

  no matches
```

**Behavior**: Shows fuzzy-matched file paths from working directory
**Components**: "no matches" state when empty

### Shell Command Prefix (!)
- **Entry**: Type `!` in input prompt
- **Type**: Direct shell command input mode
- **Behavior**: Runs shell commands directly, bypassing AI

## Keybindings

| Key | Context | Action |
|-----|---------|--------|
| `?` | Main | Show shortcuts help overlay |
| `/` | Main | Open slash command autocomplete |
| `@` | Main | Open file path autocomplete |
| `!` | Main | Shell command prefix (direct execution) |
| `Enter` | Main | Submit message |
| `Ctrl+J` | Main | Insert newline (multi-line input) |
| `Tab` | Main | Queue message |
| `Ctrl+V` | Main | Paste images |
| `Ctrl+G` | Main | Edit in external editor |
| `Esc Esc` | Main | Edit previous message |
| `Ctrl+C` | Main | Exit |
| `Ctrl+T` | Main | View transcript |
| `Escape` | Working | Interrupt AI processing |
| `↑/↓` | Selection | Navigate list items |
| `Enter` | Selection | Confirm selection |
| `Escape` | Selection/Dialog | Close/Go back |
| `Home/End` | Transcript | Jump to start/end |
| `PgUp/PgDn` | Transcript | Page scroll |
| `q` | Transcript | Quit transcript view |

## Color Palette (from ANSI analysis)

| ANSI Code | Color | Usage |
|-----------|-------|-------|
| `[2m` | Dim/Muted | Borders, secondary text |
| `[3m` | Italic | AI thinking text |
| `[1m` | Bold | Emphasis, section headers |
| `[4m` | Underline | Links |
| `[38;5;1m` | Red (Color 1) | Error/interrupt indicator (■) |
| `[38;5;5m` | Magenta (Color 5) | User input prefix (›) |
| `[38;5;6m` | Cyan (Color 6) | Tool names, links, hints |

**Style Patterns**:
- Dim + Italic (`[2;3m`): AI reasoning/thinking text
- Bold (`[1m`): Section headers ("Explored"), prompt indicator (›)
- Dim (`[2m`): Borders, secondary information, tree connectors
- Cyan (`[38;5;6m`): Interactive elements, tool names, hyperlinks

## Component Inventory

| Component | Description | Used In |
|-----------|-------------|---------|
| **Bordered Box** | Rounded corners (`╭╮╰╯`) with `│` sides | Header, status panel |
| **Bullet List** | `•` prefixed items | AI response blocks |
| **Tree View** | `└` connectors, indented | Tool call hierarchy |
| **Progress Bar** | `[████████████████████]` | Rate limits |
| **Radio Select** | Numbered options with `›` indicator | Model selection |
| **Autocomplete** | Bottom dropdown with fuzzy search | Commands, files |
| **Scroll View** | ↑/↓ indicators, position % | Transcript |
| **Status Bar** | Bottom-aligned, hints + metrics | All views |
| **Working Indicator** | `• Working (Xs • esc to interrupt)` | AI processing |
| **Ghost Text** | Dim placeholder suggestion | Input prompt |

## State Transitions

| From | Trigger | To |
|------|---------|-----|
| Main | Submit prompt | AI Working |
| AI Working | Response complete | Main (with response) |
| AI Working | Escape | Interrupted |
| Main | `/command` | Command Menu |
| Main | `?` | Help Overlay |
| Main | `Ctrl+T` | Transcript View |
| Command Menu | Enter | Execute command / Sub-dialog |
| Dialog | Escape | Previous view / Main |
| Transcript | `q` | Main |

## Data Structures

| Type | Description | Example |
|------|-------------|---------|
| **Session** | Chat conversation with metadata | UUID, timestamps, branch |
| **Message** | User or AI message | Prompt text, response blocks |
| **Tool Call** | AI tool invocation | Shell command, file read |
| **Tool Result** | Output from tool | Stdout, timing info |
| **Response Block** | Collapsible AI output section | Thinking, Explored, etc. |

## Implementation Notes

### Patterns Identified

1. **Streaming Chat Interface**: Messages appear incrementally with real-time updates
2. **Tool Call Visualization**: Hierarchical tree view of tool invocations with collapsible detail
3. **Multi-Modal Input**: Text + image paste support (Ctrl+V)
4. **Overlay System**: Help, autocomplete, dialogs appear as overlays without leaving main view
5. **Full-Screen Modes**: Transcript, session picker take over entire screen
6. **Progress Indicators**: Working spinner, progress bars, percentage indicators
7. **Contextual Hints**: Ghost text suggestions, bottom status bar hints
8. **Rate Limiting Display**: Visual progress bars with reset time annotations
9. **Session Persistence**: Resume/fork previous conversations
10. **Approval/Sandbox Modes**: Configurable execution safety levels

### Recommended Tech Stack

For cloning Codex TUI:

- **Framework**: Ratatui (Rust) - matches observed patterns
- **Async Runtime**: Tokio for streaming responses
- **State Management**: Enum-based state machine for views/modes
- **Input Handling**: Crossterm events with key chord support
- **Layout**: Constraint-based layout with responsive breakpoints
- **Text Rendering**: Unicode-aware with ANSI styling
- **Persistence**: Local file storage for session history

### Complexity Assessment

| Component | Complexity | Notes |
|-----------|------------|-------|
| Main chat interface | Medium | Streaming text, scrolling, input |
| Tool call tree | Medium-High | Collapsible hierarchy, timing |
| Autocomplete dropdowns | Medium | Fuzzy search, keyboard nav |
| Transcript view | Low | Scrollable text viewer |
| Selection dialogs | Medium | Radio groups, multi-step flows |
| Status panel | Low | Static info display |
| Progress bars | Low | Simple rendering |
| Session management | Medium | File I/O, UUID handling |
| AI integration | High | Streaming API, tool use protocol |

### Key Differentiators from Claude Code

1. **Model Selection UI**: Multi-step dialog with reasoning level
2. **Approval Policies**: More granular (untrusted, on-failure, on-request, never)
3. **Sandbox Modes**: Explicit security levels (read-only, workspace-write, full-access)
4. **Progress Bars**: Rate limit visualization with reset times
5. **Session Branching**: Fork previous sessions, not just resume
6. **MCP Integration**: Experimental MCP server support

### Minimal Clone Scope

For a basic clone that captures core UX:

1. **Must Have**:
   - Main chat with streaming responses
   - Slash command menu
   - Help overlay
   - Working/interrupt indicators
   - Status bar with context %

2. **Nice to Have**:
   - Transcript view
   - Session resume
   - Model selection
   - File autocomplete

3. **Can Defer**:
   - MCP integration
   - Image paste
   - External editor
   - Branch/fork

