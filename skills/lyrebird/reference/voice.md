# Voice

Create or refresh the root `VOICE.md` file that all other Lyrebird commands use.

## Step 1: Load Existing Voice

Run:

```bash
node .agents/skills/lyrebird/scripts/load-voice.mjs
```

Use the JSON response to determine whether `VOICE.md` exists and where it was found.

Never overwrite an existing non-placeholder `VOICE.md` without confirming with the user. Placeholder-like means empty, mostly TODO markers, or too thin to guide writing.

## Step 2: Inspect Project Context

Before asking questions, inspect what the repository already says:

- `README.md`, docs, marketing pages, blog drafts, social drafts, launch notes.
- Product docs, positioning docs, campaign plans, pricing or GTM notes.
- Existing `VOICE.md`, `PRODUCT.md`, `DESIGN.md`, `CLAUDE.md`, `AGENTS.md`, or `.agents/context/` files.
- Any public website copy or package metadata that clearly identifies the company, product, or audience.

Summarize what you inferred and what remains unclear. Ask only for gaps.

## Step 3: Interview the User

Ask 2-4 questions per round and wait for answers. Complete at least one real user-answer round unless the repository already contains complete and current source material.

Cover these areas:

1. **Subject**
   - Who or what is Lyrebird writing for?
   - Is the voice personal, founder-led, company-led, product-led, or community-led?
2. **Audience**
   - Who should understand and care?
   - What do they already know, and what jargon should be translated?
3. **Marketing Strategy**
   - What is the current GTM or content strategy?
   - What conversion, trust, hiring, community, or education goal should content support?
4. **Exemplars**
   - Ask for 3-5 links to existing content by the person/company, or
   - Ask for writers, brands, posts, newsletters, or communities whose sound they want to emulate.
5. **Sources**
   - Which sources matter most for current/trending information?
   - Which sources should be avoided?
6. **Platform Rules**
   - Ask for platform-specific preferences or constraints for Blog, LinkedIn, Reddit, and X.
7. **Anti-Voice**
   - Ask what the content must never sound like.
   - Ask for banned phrases, claims, tones, comparisons, or tactics.
8. **Link Tracking (UTM)**
   - Do they tag backlinks to their own site with UTM parameters? If not, skip this section.
   - Which domain(s) are theirs, so only owned destinations get tagged and third-party or citation links are left alone?
   - What `utm_medium` and `utm_campaign` convention do they use? A common default is `social` for medium and the proposal slug for campaign.
   - What `utm_source` token should represent each platform? Confirm the X token in particular, since teams use either `x` or `twitter`.
   - Which parameters must appear on every owned backlink?

Do not promise to clone a living writer. Extract transferable traits: pacing, density, humor, specificity, vocabulary, argument style, examples, and rhetorical moves.

## Step 4: Draft VOICE.md

Write `VOICE.md` at the project root by default.

Template:

```markdown
# Voice

## Subject

[Person, company, product, or community being written for.]

## Audience

[Primary and secondary audiences, their context, assumed knowledge, and what they need translated.]

## Marketing Strategy

[Current strategy, business goal, content role, conversion or trust objective, positioning constraints.]

## Voice and Tone

[Core voice, tone range, pacing, density, humor, attitude, formality, confidence level.]

## Platform Rules

### Blog

### LinkedIn

### Reddit

### X

## Link Tracking (UTM)

Lyrebird reads this block to tag backlinks to your own destinations. Only links to `owned_domains` are tagged; third-party and citation links are left untouched. Omit the section or set `enabled: false` if you do not use UTM tracking.

- enabled: true
- owned_domains: example.com, blog.example.com
- utm_medium: social
- utm_campaign: [default campaign, often the proposal slug]
- utm_source_blog: blog
- utm_source_linkedin: linkedin
- utm_source_reddit: reddit
- utm_source_x: x
- required: utm_source, utm_medium, utm_campaign

## Source Priorities

[Preferred sources for trends, facts, news, technical claims, market claims, and community sentiment.]

## Evidence Standards

[How strong claims need to be, acceptable source types, citation style, uncertainty handling.]

## Preferred Language

[Vocabulary, phrases, metaphors, examples, analogies, recurring framing.]

## Anti-Voice

[Banned tones, phrases, tactics, comparisons, claims, AI-writing smells, and platform behaviors.]

## Exemplars

[Links or named references, with notes on what to borrow and what not to borrow.]

## Common Phrases

## Metaphors and Analogies

## Narrative Patterns

## Claims to Avoid

## Competitors and Comparisons
```

## Step 5: Refresh Context and Resume

After writing, run `load-voice.mjs` again and consume the full JSON output so the current session uses fresh context.

If `/lyrebird voice` was invoked as a blocker for another command, resume that original command after the refresh.
