# Platform Contracts

Use this file for stable output shapes. Do not treat the limits below as current platform policy. Always browse for current rules and best practices before `/lyrebird write` or `/lyrebird modify`.

## Shared Metadata

Every platform file starts with YAML frontmatter:

```markdown
---
platform: ""
title: ""
description: ""
audience: ""
tags: []
image: ""
sources: []
created: "YYYY-MM-DD"
---
```

Allowed `platform` values: `blog`, `linkedin`, `reddit`, `x`.

Use factual source entries with access dates:

```yaml
sources:
  - title: "Source title"
    url: "https://example.com/source"
    accessed: "YYYY-MM-DD"
    supports: "Claim or platform rule this source supports"
```

Do not put image CDN URLs in `sources`; record image source and license details in `image.md`.

## Blog

File: `blog.md`

Expected content:

- Clear title and description.
- Article body with coherent argument.
- Source links for factual claims.
- Optional image reference.
- Headings only where they improve scanability.
- No generic SEO filler.

## LinkedIn

File: `linkedin.md`

Expected content:

- Strong opening line.
- Short paragraphs.
- Professional but not corporate voice.
- One clear idea or argument.
- Restrained hashtags only when they help discovery.
- Avoid engagement bait and manufactured vulnerability.

## Reddit

File: `reddit.md`

Expected content:

- Subreddit-aware title and body.
- Community-native framing.
- Transparent affiliation when relevant.
- Low-pressure or no CTA.
- No disguised marketing.
- Include subreddit rules checked in metadata or notes when a subreddit is specified.

## X

File: `x.md`

Expected content:

- Thread or single-post format.
- Clearly marked reply boundaries:

```markdown
## Reply 1

...

## Reply 2

...
```

- Each reply must satisfy the current character limit discovered at runtime.
- Links and media should be planned deliberately; do not stuff every reply with links.

## Runtime Checks

Before finalizing:

- Confirm current character limits, link behavior, media rules, hashtag norms, and platform-specific restrictions.
- Confirm whether paid account status changes limits when the user cares about X.
- Confirm subreddit-specific rules when writing for Reddit.
- Cite sources used for platform constraints in metadata or a notes section.
