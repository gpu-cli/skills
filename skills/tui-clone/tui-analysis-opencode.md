# OpenCode TUI Analysis

## Overview

- **Purpose**: AI-powered coding assistant CLI that provides a conversational interface for code generation, editing, and exploration
- **Technology Stack**: Bun/TypeScript (based on `/$bunfs/` paths seen in console), tree-sitter for syntax highlighting
- **Version Analyzed**: 1.1.48
- **Target Users**: Developers who want an AI coding assistant in their terminal

## Architecture

### Main Views/Screens Identified

1. **Home View** (Welcome/Empty State)
2. **Chat View** (Conversation with AI)
3. **Command Palette** (Ctrl+P)
4. **Model Selector**
5. **Agent Selector**
6. **Session List**
7. **Theme Picker**
8. **Provider Connect**
9. **MCP Servers List**
10. **Status View**
11. **Sidebar (Context Panel)**
12. **Timeline (Jump to Message)**
13. **Debug Panel** (overlay)
14. **Console Panel** (overlay)
15. **Help Dialog**

### Navigation Model

- **Primary**: Command palette (`Ctrl+P`) for all actions
- **Secondary**: Slash commands (`/`) in input field
- **Chord keybindings**: `Ctrl+X` prefix for common actions
- **Modal dialogs**: Escape to close all overlays
- **Context menus**: Fuzzy search filtering in selectors

### State Management

- Session-based conversations with persistence
- Real-time token counting and cost tracking
- LSP integration for file context
- Multi-provider model support with favorites

---

## Screen Catalog

### 1. Home View (Welcome Screen)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                              ▄                                                  │
│                                 █▀▀█ █▀▀█ █▀▀█ █▀▀▄ █▀▀▀ █▀▀█ █▀▀█ █▀▀█                        │
│                                 █  █ █  █ █▀▀▀ █  █ █    █  █ █  █ █▀▀▀                        │
│                                 ▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀                        │
│                                                                                                 │
│                                                                                                 │
│                               ┃                                                                 │
│                               ┃  Ask anything... "Fix a TODO in the codebase"                  │
│                               ┃                                                                 │
│                               ┃  Build  GLM 4.7 Cerebras                                       │
│                               ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀│
│                                                                       tab agents  ctrl+p commands│
│                                                                                                 │
│                                                                                                 │
│                                 ● Tip OpenCode auto-handles OAuth for remote MCP servers...    │
│                                                                                                 │
│                                                                                                 │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│  /path/to/project:HEAD                                                                  1.1.48 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Components**:
- ASCII art logo (block characters)
- Input area with placeholder text (rotates suggestions)
- Agent mode indicator (Build/Plan)
- Model indicator
- Hints bar showing `tab agents` and `ctrl+p commands`
- Random tip display with `●` bullet
- Status bar: project path, git branch, version

**Interactive Elements**:
- Text input field (multi-line capable)
- Tab to cycle agents
- Enter to submit

---

### 2. Chat View (Conversation)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│  ┃                                                                                              │
│  ┃  # Session Title                                                  11,154  9% ($0.00) v1.1.48│
│  ┃                                                                                              │
│                                                                                                 │
│  ┃  [Thinking block - collapsible]                                                              │
│  ┃  I should first explore the codebase to understand...                                       │
│                                                                                                 │
│     I'll help you with that. Let me search for relevant files.                                 │
│                                                                                                 │
│     ✱ Grep "pattern"                                                                            │
│                                                                                                 │
│     ✱ Glob "**/files*"                                                                          │
│     Error: No such file or directory                                                            │
│                                                                                                 │
│     $ pwd && ls -la                                                                             │
│     [command output]                                                                            │
│                                                                                                 │
│     Here's what I found:                                                                        │
│     1. First item                                                                               │
│     2. Second item                                                                              │
│                                                                                                 │
│     ▣  Build · model-name · 5.1s                                                                │
│                                                                                                 │
│  ┃                                                                                              │
│  ┃  [User input area]                                                                           │
│  ┃                                                                                              │
│  ┃  Build  GLM 4.7 Cerebras                                                                    │
│  ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀│
│                                                                       tab agents  ctrl+p commands│
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Components**:
- Session title (top, with `#` prefix)
- Token count, usage percentage, cost estimate
- Left margin with `┃` for user messages
- Thinking blocks (collapsible, italicized)
- Tool calls with `✱` prefix (Grep, Glob, etc.)
- Shell commands with `$` prefix
- Error messages inline
- Response completion indicator: `▣  Agent · model · duration`
- Input area at bottom

**Message Types**:
- User message: indented with `┃` margin
- Assistant response: no margin, markdown rendered
- Thinking: indented with `┃`, lighter color
- Tool call: `✱ ToolName "args"`
- Tool error: `Error: message`
- Shell: `$ command`

---

### 3. Command Palette

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Commands                              esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         Search                                       │
│                         [search input]                               │
│                                                                      │
│                         Suggested                                    │
│                         Share session                                │
│                         Switch session                    ctrl+x l   │
│                         New session                       ctrl+x n   │
│                         Switch model                      ctrl+x m   │
│                                                                      │
│                         Session                                      │
│                         Open editor                       ctrl+x e   │
│                         Share session                                │
│                         Rename session                      ctrl+r   │
│                         Jump to message                   ctrl+x g   │
│                         Fork from message                            │
│                         Compact session                   ctrl+x c   │
│                         Undo previous message             ctrl+x u   │
│                         Show sidebar                      ctrl+x b   │
│                         Disable code concealment          ctrl+x h   │
│                         Show timestamps                              │
│                         Hide thinking                                │
│                         Hide tool details                            │
│                         Toggle session scrollbar                     │
│                         Copy last assistant message       ctrl+x y   │
│                         Copy session transcript                      │
│                         Export session transcript         ctrl+x x   │
│                                                                      │
│                         System                                       │
│                         View status                       ctrl+x s   │
│                         Switch theme                      ctrl+x t   │
│                         Toggle appearance                            │
│                         Help                                         │
│                         Open docs                                    │
│                         Exit the app                                 │
│                         Toggle debug panel                           │
│                         Toggle console                               │
│                         Write heap snapshot                          │
│                         Disable terminal title                       │
│                         Disable animations                           │
│                         Disable diff wrapping                        │
│                                                                      │
│                         Agent                                        │
│                         Switch model                      ctrl+x m   │
│                         Switch agent                      ctrl+x a   │
│                         Toggle MCPs                                  │
│                         Connect provider                  ctrl+a     │
└──────────────────────────────────────────────────────────────────────┘
```

**Organization**:
- Suggested (contextual)
- Session management
- System settings
- Agent configuration

---

### 4. Model Selector

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Select model                          esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         Search                                       │
│                         [search input]                               │
│                                                                      │
│                         Recent                                       │
│                         Kimi K2.5 Fireworks AI                       │
│                         GLM 4.7 Fireworks AI                         │
│                       ● GLM 4.7 Cerebras                             │
│                         MiniMax-M2 Fireworks AI                      │
│                                                                      │
│                         OpenCode Zen                                 │
│                         GLM-4.7 Free                          Free   │
│                         Kimi K2.5 Free                        Free   │
│                         MiniMax M2.1 Free                     Free   │
│                         Trinity Large Preview                 Free   │
│                                                                      │
│                         Cerebras                                     │
│                         GPT OSS 120B                                 │
│                         Qwen 3 235B Instruct                         │
│                                                                      │
│                         Fireworks AI                                 │
│                         DeepSeek V3.1                                │
│                         DeepSeek V3.2                                │
│                         ...                                          │
│                                                                      │
│               Connect provider ctrl+a  Favorite ctrl+f               │
└──────────────────────────────────────────────────────────────────────┘
```

**Features**:
- Fuzzy search
- Recent models section
- Provider grouping (OpenCode Zen, Cerebras, Fireworks AI, Google, Vertex, etc.)
- Free tier indicators
- Current selection marked with `●`
- Connect provider shortcut (`Ctrl+A`)
- Favorite shortcut (`Ctrl+F`)

---

### 5. Agent Selector

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Select agent                          esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         Search                                       │
│                         [search input]                               │
│                                                                      │
│                       ● build native                                 │
│                         plan native                                  │
└──────────────────────────────────────────────────────────────────────┘
```

**Agents**:
- `build` - For implementing/building code
- `plan` - For planning implementations

---

### 6. Session List

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Sessions                              esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         Search                                       │
│                         [search input]                               │
│                                                                      │
│                         Today                                        │
│                       ● Directory listing request            10:31 AM│
│                                                                      │
│                         Thu Jan 29 2026                              │
│                         Live query subscription testing     11:49 PM │
│                                                                      │
│                         Tue Jan 27 2026                              │
│                         New session - 2026-01-28T02:28:05    7:28 PM │
│                         Conversation quick check-in          7:16 PM │
│                                                                      │
│                                                                      │
│                  delete ctrl+d  rename ctrl+r                        │
└──────────────────────────────────────────────────────────────────────┘
```

**Features**:
- Grouped by date
- Session title auto-generated from first message
- Timestamp display
- Current session marked with `●`
- Delete and rename shortcuts

---

### 7. Theme Picker

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Themes                                esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         Search                                       │
│                         [search input]                               │
│                                                                      │
│                         aura                                         │
│                         ayu                                          │
│                         carbonfox                                    │
│                         catppuccin                                   │
│                         catppuccin-frappe                            │
│                         catppuccin-macchiato                         │
│                         cobalt2                                      │
│                         cursor                                       │
│                         dracula                                      │
│                         everforest                                   │
│                         flexoki                                      │
│                         github                                       │
│                         gruvbox                                      │
│                         kanagawa                                     │
│                         lucent-orng                                  │
│                         material                                     │
│                         matrix                                       │
│                         mercury                                      │
│                         monokai                                      │
│                         nightowl                                     │
│                       ● nord                                         │
│                         one-dark                                     │
│                         opencode                                     │
│                         orng                                         │
│                         osaka-jade                                   │
│                         palenight                                    │
│                         rosepine                                     │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 8. Provider Connect

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Connect a provider                         esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         Search                                       │
│                         [search input]                               │
│                                                                      │
│                         Popular                                      │
│                         OpenCode Zen (Recommended)       Connected   │
│                         Anthropic (Claude Max or API key)            │
│                         GitHub Copilot                               │
│                         OpenAI (ChatGPT Plus/Pro or API key)         │
│                         Google                           Connected   │
│                                                                      │
│                         Other                                        │
│                         Privatemode AI                               │
│                         Moonshot AI (China)                          │
│                         Firmware                                     │
│                         Nova                                         │
│                         LucidQuery AI                                │
│                         ...                                          │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 9. Status View

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Status                                esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         OpenCode v1.1.48                             │
│                                                                      │
│                         No MCP Servers                               │
│                                                                      │
│                         4 Formatters                                 │
│                         • uv                                         │
│                         • terraform                                  │
│                         • rustfmt                                    │
│                         • gofmt                                      │
│                                                                      │
│                         No Plugins                                   │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 10. Sidebar (Context Panel)

```
                                                    ┌──────────────────────────────┐
                                                    │ Session Title                │
                                                    │                              │
                                                    │ Context                      │
                                                    │ 11,154 tokens                │
                                                    │ 9% used                      │
                                                    │ $0.00 spent                  │
                                                    │                              │
                                                    │ LSP                          │
                                                    │ LSPs will activate as files  │
                                                    │ are read                     │
                                                    │                              │
                                                    │                              │
                                                    │                              │
                                                    │                              │
                                                    ├──────────────────────────────┤
                                                    │ /path/to/project:HEAD        │
                                                    │ • OpenCode 1.1.48            │
                                                    └──────────────────────────────┘
```

**Sections**:
- Session title
- Context: token count, usage %, cost
- LSP status
- Project path and version

---

### 11. Timeline (Jump to Message)

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Timeline                              esc    │
├──────────────────────────────────────────────────────────────────────┤
│                         Search                                       │
│                         [search input]                               │
│                                                                      │
│                         Testing LIVE query subscription     11:49 PM │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 12. Debug Panel (Overlay)

```
                                                    ┌──────────────────────────────┐
                                                    │ Debug Information            │
                                                    │ FPS: 6                       │
                                                    │ Frame: 3256.664ms            │
                                                    │ Frame Callback: 0.330ms      │
                                                    │ Overall: 0.801ms             │
                                                    │ Render: 0.062ms              │
                                                    │ Stdout: 0.418ms              │
                                                    │ Cells: 5600                  │
                                                    │ Threaded: Yes                │
                                                    └──────────────────────────────┘
```

---

### 13. Console Panel (Overlay)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Console(Focused)                                                                                │
│ [10:31:10] [LOG] 'navigate' { type: 'session', sessionID: '...' }                              │
│ [10:31:10] [LOG] '{"type":"session",...}'                                                       │
│ [10:31:21] [LOG] 'TSWorker:' 'Loading from local path: ...'                                    │
│ ...                                                                                             │
│>[10:31:43] [LOG] 'navigate': { type: 'home', initialPrompt: undefined }                        │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 14. Slash Command Menu

```
                               ┃ /agents               Switch agent                              ┃
                               ┃ /connect              Connect provider                          ┃
                               ┃ /editor               Open editor                               ┃
                               ┃ /exit                 Exit the app                              ┃
                               ┃ /find-skills:skill    Helps users discover skills              ┃
                               ┃ /help                 Help                                      ┃
                               ┃ /init                 create/update AGENTS.md                   ┃
                               ┃ /mcps                 Toggle MCPs                               ┃
                               ┃ /models               Switch model                              ┃
                               ┃ /new                  New session                               ┃
                               ┃ /review               review changes [commit|branch|pr]         ┃
                               ┃ /sessions             Switch session                            ┃
                               ┃ /skill-creator:skill  Guide for creating skills                ┃
```

---

### 15. Agent Mentions (@)

```
                               ┃ @general              General purpose agent                     ┃
                               ┃ @explore              Exploration agent                         ┃
```

---

## Keybindings

### Global

| Key | Action |
|-----|--------|
| `Ctrl+P` | Open command palette |
| `Escape` | Close overlay/dialog, cancel |
| `Tab` | Cycle agents (in input) |
| `Enter` | Submit message / Select item |
| `PageUp` | Scroll up in conversation |
| `PageDown` | Scroll down in conversation |

### Chord Keybindings (Ctrl+X prefix)

| Key | Action |
|-----|--------|
| `Ctrl+X l` | Switch session |
| `Ctrl+X n` | New session |
| `Ctrl+X m` | Switch model |
| `Ctrl+X a` | Switch agent |
| `Ctrl+X e` | Open editor (external) |
| `Ctrl+X s` | View status |
| `Ctrl+X t` | Switch theme |
| `Ctrl+X h` | Hide tips / Disable code concealment |
| `Ctrl+X b` | Show/hide sidebar |
| `Ctrl+X g` | Jump to message (timeline) |
| `Ctrl+X c` | Compact session |
| `Ctrl+X u` | Undo previous message |
| `Ctrl+X y` | Copy last assistant message |
| `Ctrl+X x` | Export session transcript |

### In Model Selector

| Key | Action |
|-----|--------|
| `Ctrl+A` | Connect provider |
| `Ctrl+F` | Favorite model |

### In Session List

| Key | Action |
|-----|--------|
| `Ctrl+D` | Delete session |
| `Ctrl+R` | Rename session |

### Input Field

| Key | Action |
|-----|--------|
| `Ctrl+U` | Clear input |
| `/` | Open slash command menu |
| `@` | Mention agent |
| `Tab` | Cycle agents |

---

## Patterns Identified

### UI Patterns

1. **Fuzzy Search Dialogs**: All selector dialogs have consistent search at top
2. **Modal Overlays**: Centered dialogs with `esc` hint in top-right
3. **Section Grouping**: Related items grouped with headers (Suggested, Session, System, etc.)
4. **Current Selection**: Marked with `●` bullet
5. **Keyboard Hints**: Shortcuts shown right-aligned in dialogs
6. **Status Bar**: Always shows project path, git branch, version

### Component Reuse

1. **SearchableList**: Used in model, session, theme, provider, command palette
2. **Dialog/Modal**: Consistent centering and escape handling
3. **InputArea**: Multi-line input with agent/model indicators
4. **MessageBlock**: Handles user, assistant, thinking, tool call rendering
5. **Sidebar**: Toggleable context panel

### Styling Conventions

- Block characters for logo (`█▀▀█`, etc.)
- `┃` for message margins
- `╹▀▀` for input area bottom border
- `✱` for tool calls
- `▣` for completion indicator
- `●` for current/active item
- `$` for shell commands

### Typography

- Markdown rendering for assistant responses
- Syntax highlighting via tree-sitter
- Thinking blocks in different color/style
- Session titles with `#` prefix

---

## Implementation Notes

### Recommended Tech Stack for Clone

| Component | Recommendation |
|-----------|----------------|
| Framework | **Ratatui** (Rust) or **Ink** (TypeScript) |
| Syntax highlighting | tree-sitter |
| Markdown rendering | pulldown-cmark + custom renderer |
| Key handling | crossterm |
| State management | Elm-like architecture with messages |
| API clients | reqwest/tokio (Rust) or fetch (TS) |

### Complexity Assessment

| Feature | Complexity | Notes |
|---------|------------|-------|
| Basic chat view | Medium | Markdown rendering, scrolling |
| Command palette | Low | Fuzzy search list |
| Model selector | Low | Grouped list with search |
| Thinking blocks | Medium | Collapsible, different styling |
| Tool call rendering | Medium | Different tool types |
| Sidebar | Low | Simple stats panel |
| Multi-line input | Medium | Cursor handling, syntax |
| Session persistence | Medium | File-based storage |
| Streaming responses | High | SSE handling, progressive render |
| LSP integration | High | Language server protocol |

### Potential Challenges

1. **Streaming Response Rendering**: Need to handle partial markdown/code blocks
2. **Tree-sitter Integration**: Loading WASM grammars, incremental parsing
3. **Multi-line Input**: Proper cursor movement, selection
4. **Theme System**: Dynamic color loading from config
5. **External Editor Integration**: Temp file management, process spawning
6. **OAuth for Providers**: Browser redirect flow in terminal app

### Key Data Structures

```rust
// Session
struct Session {
    id: String,
    title: String,
    messages: Vec<Message>,
    created_at: DateTime,
    updated_at: DateTime,
}

// Message types
enum Message {
    User { content: String },
    Assistant {
        content: String,
        thinking: Option<String>,
        tool_calls: Vec<ToolCall>,
        model: String,
        duration: Duration,
    },
}

// Tool call
struct ToolCall {
    tool_type: ToolType,  // Grep, Glob, Bash, Read, Write, etc.
    args: String,
    result: Option<String>,
    error: Option<String>,
}

// App state
struct AppState {
    current_view: View,
    sessions: Vec<Session>,
    current_session: Option<SessionId>,
    input_buffer: String,
    agent: Agent,  // Build, Plan
    model: Model,
    sidebar_visible: bool,
    debug_visible: bool,
    console_visible: bool,
}
```

### Layout Calculations

```
Full screen (140x40 typical):
┌──────────────────────────────────────────────────────────────────────────────────────────────┬───────────────────┐
│ Main content area (75-80%)                                                                   │ Sidebar (20-25%)  │
│ - Messages                                                                                   │ - Context stats   │
│ - Tool outputs                                                                               │ - LSP status      │
│ - Input area (4-6 lines at bottom)                                                          │                   │
├──────────────────────────────────────────────────────────────────────────────────────────────┴───────────────────┤
│ Status bar (1 line)                                                                                              │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

Input area breakdown:
┃                                           <- left margin (2 chars)
┃  [message content, multi-line]            <- content area
┃
┃  Agent  Model Provider                    <- status line
╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀   <- bottom border
                    tab agents  ctrl+p commands  <- hints
```

---

## File Locations (for reference)

Based on console output, OpenCode uses:
- `/$bunfs/root/` - Bundled assets (tree-sitter grammars, etc.)
- Session IDs: `ses_[random]` format
- Navigate events for routing

---

## Summary

OpenCode is a polished AI coding assistant TUI with:
- Clean modal architecture
- Comprehensive keyboard shortcuts with chord system
- Multi-provider model support
- Session management with persistence
- Real-time cost tracking
- Extensible via MCP servers and skills

For cloning, focus on:
1. Core chat loop with streaming
2. Command palette pattern
3. Session/model selectors
4. Basic tool call rendering
5. Add LSP and advanced features later
