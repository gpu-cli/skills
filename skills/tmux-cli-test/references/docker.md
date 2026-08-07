# Testing CLIs Inside Docker Containers

For a CLI running inside a container (for example FTR testing), source the
Docker helpers instead of the local ones and name the container once:

```bash
source .claude/skills/tmux-cli-test/scripts/tmux_docker_helpers.sh
TMUX_DOCKER_CONTAINER="gpu-ftr-alex-chen-001"
# TMUX_DOCKER_SESSION="test"   # default; override if needed
```

Every `docker_tmux_*` call then routes through `docker exec` to that container.
Same semantics as the local helpers, minus the session and container arguments.

| Function | Purpose |
|----------|---------|
| `docker_tmux_send <keys...>` | Send tmux keys |
| `docker_tmux_type <text>` | Type literal text |
| `docker_tmux_capture` | Get pane text |
| `docker_tmux_capture_ansi` | Get pane text with ANSI codes |
| `docker_tmux_wait_for <text> [timeout]` | Poll until text appears |
| `docker_tmux_wait_regex <pattern> [timeout]` | Poll until regex matches |
| `docker_tmux_wait_gone <text> [timeout]` | Poll until text disappears |
| `docker_tmux_assert_contains <text> [label]` | Assert text present |
| `docker_tmux_assert_not_contains <text> [label]` | Assert text absent |
| `docker_tmux_assert_matches <pattern> [label]` | Assert regex matches |
| `docker_tmux_send_and_wait <keys> <text> [timeout]` | Send then wait |

## Example

```bash
source .claude/skills/tmux-cli-test/scripts/tmux_docker_helpers.sh
TMUX_DOCKER_CONTAINER="gpu-ftr-alex-chen-001"

docker_tmux_send "gpu dashboard" Enter
docker_tmux_wait_for "Pods" 15
docker_tmux_capture

docker_tmux_send j
docker_tmux_send "?"
docker_tmux_wait_for "Help" 5
docker_tmux_assert_contains "Keybindings" "help shows keybindings"
docker_tmux_send Escape
docker_tmux_wait_gone "Help" 5
docker_tmux_send q
```

There is no `docker_tmux_kill`: the session lives inside the container, so tear
it down with the container itself, or send the app's own quit key as above.
