# Write

Use `/lyrebird write [platform?] [proposal]` to create final platform-native post files.

If no platform is specified, write all supported platforms: Blog, LinkedIn, Reddit, and X.

## Inputs

- Proposal text, ideally from `/lyrebird hone`.
- Optional platform: `blog`, `linkedin`, `reddit`, or `x`.
- Loaded `VOICE.md`.

## Workflow

1. Load `VOICE.md`.
2. Parse the platform argument:
   - no platform means `blog`, `linkedin`, `reddit`, and `x`,
   - a platform means only that platform.
3. Load `platform-contracts.md`, `editorial-quality.md`, and `sourcing-and-fact-checking.md`.
4. Browse for current platform rules and best practices for each requested platform.
5. Research the factual claims in the proposal. Prefer primary sources.
6. Create a stable slug from the proposal title or thesis:
   - lowercase,
   - words separated with hyphens,
   - no punctuation except hyphens,
   - concise enough for a directory name.
7. Create `social/<proposal-slug>/`.
8. Find one appropriate high-definition, free-to-use image for the content:
   - prefer Unsplash, Lummi, Pexels, or another source with clear usage terms,
   - if downloading is not possible, create image metadata instead,
   - record source URL, creator/credit if available, license or usage note, and alt text.
9. Draft each requested platform in the voice from `VOICE.md`.
10. Validate claims and fix clearly false or unsupported statements.
11. Rephrase anything the intended audience is unlikely to understand.
12. Remove AI-writing smell.
13. Validate files with `validate-social-output.mjs`.
14. Report created file paths and any claims that remain uncertain.

## Output Files

Default output:

```text
social/<proposal-slug>/
  blog.md
  linkedin.md
  reddit.md
  x.md
  image.md or image file
```

If one platform is requested, create only that platform file plus image metadata or image file.

## Metadata Header

Each platform file starts with YAML frontmatter:

```markdown
---
platform: "linkedin"
title: ""
description: ""
audience: ""
tags: []
image: ""
sources: []
created: "YYYY-MM-DD"
---
```

Use valid YAML. Keep `sources` as URLs or objects with `title`, `url`, and `accessed`.

## Platform Notes

- Blog: full article, source-aware, clear title and description.
- LinkedIn: professional, scannable, concrete, restrained hashtags.
- Reddit: subreddit-aware, community-native, transparent affiliation when relevant, no disguised marketing.
- X: thread-ready, with each reply clearly marked:

```markdown
## Reply 1

[Text]

## Reply 2

[Text]
```

## Validation

Run:

```bash
node {{scripts_path}}/validate-social-output.mjs --mode write --dir social/<proposal-slug> --platforms blog,linkedin,reddit,x
```

Pass only the requested platforms for single-platform output.
