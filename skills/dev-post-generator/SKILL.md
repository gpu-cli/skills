---
name: dev-post-generator
description: "Generate social media content from code changes. Analyzes branch diffs, researches platform best practices, presents content ideas for selection, captures visual assets, and produces platform-optimized post packages. Use before merging to create announcements for Twitter/X, LinkedIn, Bluesky, Mastodon, or Reddit."
---

# Dev Post Generator

Generate social media content from code changes — from branch diff to publish-ready post packages.

## When to Use This Skill

- Before merging a feature branch — announce what you shipped
- After reaching a milestone — celebrate progress
- When creating a release announcement — structured multi-platform rollout
- After fixing a notable bug — share the story
- When launching a new open source project — first impressions matter

## Configuration

Environment variables (all optional — asked if needed):

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVPOST_OUTPUT_DIR` | `social-posts` | Base directory for output packages |
| `DEVPOST_BRANCH` | current branch | Branch to analyze |
| `DEVPOST_BASE_BRANCH` | `main` | Base branch for diff comparison |
| `DEVPOST_PLATFORMS` | asked | Comma-separated: `twitter,linkedin,bluesky,mastodon,reddit` |
| `DEVPOST_TREND_SOURCES` | none | Comma-separated search terms/topics for trend research |
| `DEVPOST_PROJECT_URL` | none | Project URL to include in posts |
| `DEVPOST_AUTHOR_HANDLE` | none | Author handle (e.g., `@username`) |

## Upfront Questions

Before beginning, use AskUserQuestion to clarify:

1. **Branch to analyze**
   - Auto-detect current branch or specify manually
   - If on main/master with no feature branch: ask for branch name or commit range

2. **Target platforms** (multi-select)
   - Twitter/X
   - LinkedIn
   - Bluesky
   - Mastodon
   - Reddit

3. **Audience context**
   - Who is the audience? (developers, product managers, general tech)
   - What is the project? (one-line description)

4. **Trend research** (opt-in)
   - Yes/No — do you want trend-aware content?
   - If yes: search terms/topics to look for (e.g., "Rust CLI tools", "developer experience")

5. **Asset preferences**
   - Project type: CLI/TUI, web app, library/API, other
   - Can it be run locally for screenshots? (yes/no)
   - Any existing assets to include? (paths)

## Output Structure

Everything is written to `social-posts/[branch-slug]-[YYYYMMDD-HHMMSS]/`:

```
social-posts/feature-dark-mode-20260219-143052/
├── README.md              # Package overview + platform research findings
├── changelog.md           # Categorized changes from the diff
├── ideas.md               # All content ideas + selection history
├── platforms/
│   ├── twitter.md         # Final post copy for Twitter/X
│   ├── linkedin.md        # Final post copy for LinkedIn
│   └── ...                # One file per selected platform
├── assets/
│   ├── before-after.png   # Visual comparisons
│   ├── code-snippet.png   # Syntax-highlighted code
│   └── ...                # All captured assets
└── metadata.json          # Structured data for downstream tooling
```

## Process

### Phase 1: Setup & Branch Analysis

1. Detect branch (use `DEVPOST_BRANCH` or current branch)
2. Create output directory:
   ```bash
   BRANCH_SLUG=$(git rev-parse --abbrev-ref HEAD | sed 's/[^a-zA-Z0-9]/-/g')
   TIMESTAMP=$(date +%Y%m%d-%H%M%S)
   OUTPUT_DIR="${DEVPOST_OUTPUT_DIR:-social-posts}/${BRANCH_SLUG}-${TIMESTAMP}"
   mkdir -p "$OUTPUT_DIR/platforms" "$OUTPUT_DIR/assets"
   ```
3. Gather diff data:
   ```bash
   BASE="${DEVPOST_BASE_BRANCH:-main}"
   git log "$BASE"..HEAD --oneline
   git diff "$BASE"...HEAD --stat
   git diff "$BASE"...HEAD
   ```
4. If `git diff --stat` returns empty: inform user there are no changes to analyze, stop
5. For large diffs (100+ files): summarize by category, selectively read the most impactful files
6. Analyze commits: count, conventional commit prefixes (feat/fix/perf/refactor/docs/test/chore)
7. Write `changelog.md` categorized by:
   - **Features** — new user-facing functionality
   - **Bug Fixes** — resolved issues
   - **Performance** — speed/memory improvements
   - **Other** — refactoring, tests, CI/CD, dependencies
8. Classify each change for social-media-worthiness:
   - **High**: new user-facing features, visual/UI changes, measurable perf improvements, DX improvements
   - **Medium**: bug fixes users complained about, API additions
   - **Low**: internal refactoring, test additions, CI/CD, deps

### Phase 2: Platform Best Practices Research

For each selected platform, research current best practices using WebSearch:

1. Search queries (run for each platform):
   - `"[platform] developer content best practices [current year]"`
   - `"[platform] character limit media format [current year]"`
2. Gather for each platform:
   - Current character limits
   - Supported media formats and dimensions
   - Hashtag strategy (how many, placement)
   - Posting patterns that work for dev content
   - What developer content performs well
3. Write findings to a "Platform Research" section in the output `README.md`

This runs fresh every time — no static reference file to maintain. Platform norms change frequently.

### Phase 3: Trend Research (Optional)

**Skip this phase if the user opted out of trend research.**

1. Use **WebSearch only** (WebFetch is domain-restricted and cannot fetch arbitrary trend feeds)
2. Search for trending topics using terms from `DEVPOST_TREND_SOURCES` or the upfront question:
   - `"[topic] trending [current year]"`
   - `"[topic] developer community discussion"`
3. Assess relevance: can the post naturally tie into this trend?
4. Write a "Trending Context" table to `README.md`:

   | Trend | Source | Relevance | Connection |
   |-------|--------|-----------|------------|
   | ... | ... | High/Med/Low | How to connect naturally |

5. **Anti-pattern**: never force trend connections — if the tie-in feels unnatural, note it and move on

### Phase 4: Idea Generation

Generate 3-5 content ideas with distinct angles. Choose from:

| Angle | Description | Best For |
|-------|-------------|----------|
| **The Announcement** | Straightforward "we shipped X" | Major features, releases |
| **The Before/After** | Visual comparison of old vs new | UI changes, perf improvements |
| **The Behind-the-Scenes** | How it was built, decisions made | Technical audiences |
| **The Problem/Solution** | Pain point that existed, how it's now fixed | Relatable bug fixes |
| **The Demo** | Show it working (screenshot/recording) | CLI tools, visual features |
| **The Thread** | Multi-post deep dive | Complex features, Twitter/X |
| **The Trend Tie-In** | Connect to current conversation | Only if natural fit from Phase 3 |

For each idea, document in `ideas.md`:
- **Title**: descriptive name
- **Angle**: which angle from the table above
- **Hook**: the first line / opening sentence (most important part)
- **Key points**: 3-5 bullet points to cover
- **Assets needed**: what visuals would support this
- **Best platform**: where this angle works best
- **Effort estimate**: low (text only) / medium (needs screenshots) / high (needs recording or thread)

### Phase 5: Interactive Selection Loop

Present ideas to the user via AskUserQuestion:

**Options:**
1. Select a specific idea (list each by title)
2. Develop all ideas for different platforms
3. Reject all — suggest new directions
4. Custom idea — user describes their own angle

**If rejected:**
1. Ask what's missing: more technical? more accessible? focus on a specific change?
2. Generate a new batch incorporating feedback
3. Write rejection reason and new batch to `ideas.md` (persists through context compaction)

**Loop limit:** After 3 rejections, suggest alternatives:
- Look at successful posts about similar projects for inspiration
- Start with a rough draft and iterate
- Try a completely different approach (e.g., from announcement to behind-the-scenes)

All loop state is persisted in `ideas.md` so progress survives context compaction.

### Phase 6: Asset Collection

Source the asset helpers:
```bash
source .claude/skills/dev-post-generator/scripts/asset_helpers.sh
```

**By project type:**

| Project Type | Primary Assets | Method |
|-------------|----------------|--------|
| CLI/TUI | Terminal screenshots, recordings | `capture_terminal_app`, `record_terminal` |
| Web app | Manual screenshots | `print_manual_screenshot_guide` |
| Library/API | Code snippets, formatted diffs | `capture_code_snippet`, `capture_diff_screenshot` |
| Other | Code snippets, diffs | `capture_code_snippet`, `capture_diff_screenshot` |

**Before/After comparisons:**
```bash
capture_before_after "$BASE" "command-to-run" "ready-text" "feature-name"
```

**If tools are not installed** (freeze, asciinema): functions skip gracefully with a message. Continue with text-only content — do not block on missing tools.

**If capture fails**: note what's missing in `README.md`, continue with text-only posts.

Write asset inventory to the output `README.md`.

### Phase 7: Post Composition

For each selected platform:

1. Compose copy following the best practices researched in Phase 2
2. Apply platform-specific formatting:
   - **Twitter/X**: hook in first line, thread structure if needed, 1-3 hashtags at end
   - **LinkedIn**: professional tone, paragraph breaks, relevant hashtags integrated
   - **Bluesky**: conversational tone, respect character limit, no hashtag overload
   - **Mastodon**: CW if appropriate, hashtags for discoverability, alt text required
   - **Reddit**: subreddit-appropriate tone, self-post format, no self-promotion feel
3. Each post file (`platforms/[platform].md`) includes:
   - Post text (ready to copy-paste)
   - Media attachments with alt text for each image
   - Posting notes: suggested timing, hashtags, cross-posting considerations
4. Present drafts to user via AskUserQuestion:
   - Approve as-is
   - Edit specific sections
   - Change tone (more casual / more professional / more technical)
   - Regenerate entirely
5. Write `metadata.json`:
   ```json
   {
     "branch": "feature/dark-mode",
     "base_branch": "main",
     "generated_at": "2026-02-19T14:30:52Z",
     "platforms": ["twitter", "linkedin"],
     "ideas_selected": ["The Before/After"],
     "assets": ["assets/before.png", "assets/after.png"],
     "commit_count": 12,
     "files_changed": 8
   }
   ```

## Quality Gates

Before finalizing output, verify:

- [ ] All posts are within platform character limits
- [ ] No placeholder text remains (no `[TODO]`, `[INSERT]`, `Lorem ipsum`)
- [ ] All referenced assets exist in the `assets/` directory
- [ ] All images have alt text written
- [ ] No sensitive data in screenshots (API keys, tokens, internal URLs, passwords)
- [ ] Opening hook is compelling — not generic ("We're excited to announce...")
- [ ] CTA is present where appropriate (link, follow, star, try it)
- [ ] Hashtags are relevant and limited (1-3 per platform, not stuffed)
- [ ] Each platform post reads naturally for that platform's culture

## Anti-Patterns

| Bad | Good | Why |
|-----|------|-----|
| "We're excited to announce..." | Lead with the value or the problem solved | Generic openings get scrolled past |
| Same copy pasted to all platforms | Tailored tone, format, and length per platform | Each platform has different norms and audiences |
| Hashtag stuffing (#coding #dev #tech #programming #software) | 1-3 targeted hashtags | Stuffing looks spammy, reduces engagement |
| "Check out our new feature!" with no context | Show what it does, why it matters | People need a reason to care |
| Wall of text with no visual | Include a screenshot, code snippet, or before/after | Visual content gets 2-3x engagement |
| Listing every change from the changelog | Pick the 1-2 most interesting changes | Social posts are not release notes |
| Forced trend connection | Only tie into trends that naturally relate | Forced connections feel inauthentic |
| Technical jargon for general audience | Match language to the target audience | Know who you're talking to |

## Resuming After Context Compaction

If context is compacted, recover state by reading the output directory:

1. Read `README.md` for package overview, platform research, and current phase
2. Read `changelog.md` for analyzed changes
3. Read `ideas.md` for generated ideas and selection history
4. Check `platforms/` for any already-composed posts
5. Check `assets/` for any already-captured assets
6. Check `metadata.json` for structured state
7. Resume from the next incomplete phase

## Instructions

1. Use AskUserQuestion to gather branch, platforms, audience, trend preference, and asset preferences
2. Detect branch and validate it has changes vs base branch — stop early if diff is empty
3. Create the output directory structure via `mkdir -p`
4. **Phase 1**: Analyze the branch diff, write `changelog.md`, classify changes
5. **Phase 2**: Research current platform best practices via WebSearch, write findings to `README.md`
6. **Phase 3**: If trend research opted in, search for trends via WebSearch, write to `README.md`
7. **Phase 4**: Generate 3-5 content ideas with distinct angles, write to `ideas.md`
8. **Phase 5**: Present ideas via AskUserQuestion, handle selection/rejection loop
9. **Phase 6**: Source `asset_helpers.sh`, capture assets based on project type (skip gracefully if tools missing)
10. **Phase 7**: Compose platform-specific posts, present for review, write final files and `metadata.json`
11. Verify all quality gates before completing
12. Present a summary to the user with the output directory path and next steps (copy-paste, schedule, etc.)
