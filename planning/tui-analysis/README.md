# TUI Analysis Archive

Past `tui-clone` outputs, kept as reference material for the benchmarking that
`tui-review` does against best-in-class AI terminal UIs.

| File | Subject |
|---|---|
| [claude-code.md](claude-code.md) | Claude Code TUI |
| [codex.md](codex.md) | Codex TUI |
| [opencode.md](opencode.md) | OpenCode TUI |

These are **generated session outputs, not skill content**. They live here
rather than under `skills/tui-clone/` because anything inside a skill directory
ships to every install of that skill and an agent reading the package can
mistake it for instructions. `scripts/skill-lint.sh` fails the build if outputs
like these reappear under `skills/`.
