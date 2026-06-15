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
   - if downloading is possible, save the image file and an `image.md` metadata file,
   - if downloading is not possible, create `image.md` metadata that points to the image URL,
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
  image.md
  <optional image file>
```

If one platform is requested, create only that platform file plus `image.md` and any downloaded image file.

## Image Metadata

Write `image.md` using these exact key-value fields so source and usage rights remain auditable:

```markdown
source: https://example.com/image-page
license: Unsplash License, free to use
credit: Creator or source name if available
alt: Short description of the image for accessibility
```

The `license` field must clearly name free-to-use terms such as Unsplash, Pexels, Lummi, Creative Commons, CC0, public domain, royalty-free, free to use, commercial use allowed, open license, or permissive usage. Do not use vague values like `unknown`, `TBD`, or a generic terms URL with no free-use language.

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

Use valid YAML. Keep `sources` as structured entries with `title`, `url`, `accessed`, and optional `supports` fields. The validator requires at least one factual evidence source with `accessed: YYYY-MM-DD`; image URLs belong in `image.md`, not `sources`.

```yaml
sources:
  - title: "Source title"
    url: "https://example.com/source"
    accessed: "YYYY-MM-DD"
    supports: "Claim or platform rule this source supports"
```

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
node .claude/skills/lyrebird/scripts/validate-social-output.mjs --mode write --dir social/<proposal-slug> --platforms blog,linkedin,reddit,x
```

Pass only the requested platforms for single-platform output.
