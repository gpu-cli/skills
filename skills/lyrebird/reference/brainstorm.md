# Brainstorm

Use `/lyrebird brainstorm [topic]` to produce 3-5 timely, defensible content takes.

## Inputs

- Topic from the user.
- Loaded `VOICE.md`.
- Current trend, news, and discourse sources.

## Workflow

1. Load `VOICE.md`.
2. Clarify the topic only if it is too broad to research usefully.
3. Search the web for current discussion:
   - recent news and primary sources,
   - platform discourse,
   - community discussions,
   - contrarian or emerging opinions,
   - search terms from `VOICE.md` source priorities.
4. Track source URLs, dates, and what each source supports.
5. Generate 5-8 candidate takes internally.
6. Run a steelman pass:
   - When subagent tools are available, spawn a separate agent to challenge the candidate takes, strengthen the best ones, and propose replacements. Give it only the topic, `VOICE.md` summary, sources, and candidate takes, not your preferred answers.
   - Compare the original candidates and steelman output. Iterate until the main agent and steelman pass converge on 3-5 takes.
   - If subagent tools are unavailable, say that explicitly in the response and perform a clearly separated adversarial review yourself.
7. Reject takes that are:
   - obvious category filler,
   - unsupported by sources,
   - pure outrage bait,
   - misaligned with `VOICE.md`,
   - likely to be misunderstood by the target audience.
8. Return 3-5 final takes.

## Output

Return a concise selection list:

```markdown
## Takes

1. [One-sentence take.]
   Why it works: [One sentence.]
   Best platforms: [Blog / LinkedIn / Reddit / X.]

2. ...

## Sources Consulted

- [Source title](URL), [what it supported], accessed YYYY-MM-DD.
```

Keep each take short enough for the user to choose quickly. Do not draft full posts in brainstorm mode.
