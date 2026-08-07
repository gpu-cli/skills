# Clone Spec Template

The shape of the analysis file. Read before writing the first section and again
before declaring the analysis finished.

## Section order

~~~markdown
# [App Name] TUI Analysis

## Overview
- Purpose:
- Technology stack:
- Target users:

## Screen Catalog
### [Screen Name]
- Entry: [how you got here]
```
[ASCII capture or diagram]
```

## Keybindings
| Key | Context | Action |
|-----|---------|--------|

## State Transitions
| From | Trigger | To |
|------|---------|-----|

## Component Inventory
| Component | Description | Observed In |
|-----------|-------------|-------------|
| List | Scrollable item list with selection | Main view, File picker |
| Modal | Centered overlay dialog | Commit message, Confirmation |
| Tabs | Numbered panel switcher | Top bar |
| Status bar | Bottom info line | All views |
| Progress | Loading/sync indicator | Push/pull operations |
| Input | Text entry field | Search, Commit message |

## Color Palette
[ANSI capture]

## Responsive Behavior
[Compact 80x24 and wide 200x50 captures]

## Error / Loading States
[Error messages, spinners, empty states, confirmation dialogs]

## Data Structures
[Lists (single/multi-select), trees, tables, text views, diffs]

## Implementation Notes
### Patterns Identified
### Recommended Tech Stack
### Complexity Assessment
~~~

## ASCII diagram conventions

```text
┌─────────────────────────────────────────┐
│ Header / Title Bar                      │
├────────────────┬────────────────────────┤
│ Sidebar        │ Main Content           │
│                │                        │
│ - Item 1       │  Details here          │
│ > Item 2 *     │                        │
│ - Item 3       │                        │
├────────────────┴────────────────────────┤
│ Status Bar / Footer                     │
└─────────────────────────────────────────┘
```

- `>` selected item
- `*` active/focused
- `[Button]` clickable
- `[x]` / `[ ]` checkbox
- `( )` / `(*)` radio button
- `│ ─ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼` borders

## What makes a good clone spec

A finished spec answers all of these. Use it as the completeness check.

| Dimension | Question to answer |
|-----------|-------------------|
| Layout | How is the screen divided? Panels, sidebars, modals? |
| Navigation | How do users move between views? Keys, menus, tabs? |
| Selection | Single-select? Multi-select? How is selection shown? |
| Input | Text fields? How do they behave? Validation? |
| Feedback | Loading states? Success/error messages? Progress? |
| Scrolling | What scrolls? How is scroll position indicated? |
| Focus | What can be focused? How is focus shown? |
| Shortcuts | Global vs context-specific? Discoverable? |
| Theming | Hard-coded colors or configurable? |
| Resize | Fixed layout or responsive? Minimum size? |
