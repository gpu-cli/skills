# Hone

Use `/lyrebird hone [idea]` to turn a rough idea into a researched content proposal.

## Inputs

- One-sentence idea or selected brainstorm take.
- Loaded `VOICE.md`.
- Current sources and repository/company context.

## Workflow

1. Load `VOICE.md`.
2. Search for current sources related to the idea.
3. Inspect repo/company context where relevant:
   - README, docs, product notes, planning docs,
   - existing blog/social content,
   - positioning or GTM material.
4. Decide on a position grounded in:
   - recent facts,
   - patterns and trends,
   - company/product point of view,
   - audience needs from `VOICE.md`.
5. Build the argument:
   - thesis,
   - stakes,
   - supporting points,
   - evidence,
   - counterarguments,
   - caveats,
   - conclusion or CTA.
6. Check audience fit. Rephrase concepts that the audience is unlikely to understand.
7. Run the editorial quality checks from `editorial-quality.md`.
8. Return a proposal for approval. Do not write the final post yet unless the user asks.

## Output

```markdown
## Proposal

### Working Title

[Title.]

### Thesis

[One clear sentence.]

### Position Summary

[Short paragraph in the user's voice.]

### Argument Outline

1. [Point.]
2. [Point.]
3. [Point.]

### Evidence to Use

- [Claim], [Source URL], accessed YYYY-MM-DD.

### Risks and Caveats

- [Risk, uncertainty, or counterargument.]

### Suggested Platforms

- Blog: [why]
- LinkedIn: [why]
- Reddit: [why]
- X: [why]
```

Use hedging when the evidence is incomplete. Remove weak claims rather than padding around them.
