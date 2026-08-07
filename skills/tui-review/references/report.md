# Screenshot Plan, Visual Checklist, and Report Format

Read this when you start capturing states and again when you write the report.

## Screenshot Plan

Capture these states during the review, and open each PNG with the Read tool as
you go.

| # | State | Label | What to look for |
|---|-------|-------|-----------------|
| 1 | Initial load | `01-initial` | First impression, layout, color usage |
| 2 | Help/shortcuts overlay | `02-help` | Discoverability, overlay design |
| 3 | Command palette / slash menu | `03-commands` | Dropdown styling, selection highlight |
| 4 | During processing/streaming | `04-processing` | Loading indicator, streaming text |
| 5 | Completed response | `05-response` | Message formatting, tool output |
| 6 | Error state | `06-error` | Error visibility, color distinction |
| 7 | Dialog/modal open | `07-dialog` | Modal design, backdrop |
| 8 | Permission/confirmation flow | `08-permission` | Diff preview, action options |
| 9–12 | Resize: 80x24, 120x30, 160x40, 200x50 | `09-resize-WxH` | Layout adaptation |

## Visual Review Checklist

Apply to every screenshot you open.

### Color
- [ ] **Semantic color** — status colors (green=success, red=error, yellow=warning) used consistently
- [ ] **Color richness** — not monochrome; color creates visual hierarchy
- [ ] **Contrast** — text readable against its background, no light-gray-on-dark-gray
- [ ] **Consistency** — the same element type is the same color everywhere
- [ ] **Restraint** — a limited palette with purpose, not a rainbow

### Layout
- [ ] **Density** — information-dense without feeling cluttered
- [ ] **Alignment** — elements align to a grid, no ragged edges
- [ ] **Whitespace** — breathing room between sections
- [ ] **Proportions** — input area, content area, and status bar are well-sized

### Typography
- [ ] **Hierarchy** — headers and titles are visually distinct
- [ ] **Readability** — reasonable line lengths, not 200-character lines
- [ ] **Symbols** — Unicode status glyphs (●, ◐, ✓, ✗) rather than ASCII

### Polish
- [ ] **No artifacts** — no stray characters, broken box-drawing, or rendering glitches
- [ ] **Consistent borders** — one border weight throughout
- [ ] **Professional feel** — would this look good in a demo or conference talk?

## Report Format

```markdown
# TUI Review: [App Name]

**Overall Grade**: [A/B/C/D/F]
**Tested at**: [terminal size] | **Binary**: [path] | **Date**: [date]
**Screenshots**: [directory path]

## Summary
[2-3 sentence verdict]

## Screenshots

### Initial State
![initial](screenshots/01-initial.png)
[Visual observations: layout, color palette, first impression]

### Key States
![help](screenshots/02-help.png)
[Visual observations for each captured state]

### Resize Behavior
![80x24](screenshots/09-resize-80x24.png) ![200x50](screenshots/09-resize-200x50.png)
[How the layout adapts]

## Scores

| # | Dimension | Grade | Issues |
|---|-----------|-------|--------|
| 1 | Responsiveness | | |
| 2 | Input Integrity | | |
| 3 | Visual Feedback | | |
| 4 | Navigation | | |
| 5 | Feedback Loops | | |
| 6 | Error States | | |
| 7 | Layout | | |
| 8 | Keyboard Design | | |
| 9 | Permission Flows | | |
| 10 | Visual Design & Color | | |

## Findings

### CRITICAL (must fix)
- [finding with file:line if known]

### WARNING (should fix)
- [finding]

### INFO (nice to have)
- [finding]

## vs Best-in-Class
[How this TUI compares to Claude Code/OpenCode/Codex patterns]
```
