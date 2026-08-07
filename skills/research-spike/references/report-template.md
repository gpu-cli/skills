# Spike Report Template and Quality Gates

Read before writing the report, and again before calling it finished.

## Template

~~~markdown
# [Research Topic]

**Type**: [Technical Spike | Competitive Research | Feasibility Analysis]
**Depth**: [Quick | Standard | Deep]
**Date**: [YYYY-MM-DD]

## Executive Summary

[One-pager synopsis, <250 words. Key findings, recommendation, and confidence
level. A busy stakeholder should be able to read only this section and
understand the conclusion.]

## Background

### Context
[Why this research was conducted, what triggered it]

### Research Question
[The specific question(s) being answered]

### Scope
[What is and isn't covered, constraints applied]

## Methodology

[Brief description of research approach, sources consulted, tools used]

## Findings

### [Finding Category 1]
[Detailed findings with evidence]

**Sources**: [Citations]

### [Finding Category 2]
[Detailed findings with evidence]

**Sources**: [Citations]

## Analysis

### Trade-offs
[Key trade-offs, with the context in which each option is preferable]

### Risks
[Potential risks, unknowns, or concerns]

### Decision Matrix (competitive research only)
| Criteria | Option A | Option B | Option C |
|----------|----------|----------|----------|
| [Factor] | [Score/Note] | [Score/Note] | [Score/Note] |

## Recommendations

### Primary Recommendation
[Clear, actionable recommendation with rationale]

### Alternative Approaches
[Other viable options if the primary doesn't fit]

### Confidence Level
[High/Medium/Low, and what would increase it]

## Next Steps

1. [Concrete action item]
2. [Concrete action item]
3. [Concrete action item]

## Appendix

### Sources
[Numbered list of all sources cited]

### Glossary (if needed)
[Definitions of technical terms]

### Raw Notes (if applicable)
[Detail that didn't fit the main sections]
~~~

## Quality Gates

Verify every one of these before finalizing:

- [ ] Every factual claim cites a source
- [ ] Executive summary is under 250 words
- [ ] Recommendations are actionable and specific
- [ ] Trade-offs are presented objectively
- [ ] Confidence level is stated with justification
- [ ] Next steps are concrete and prioritized
- [ ] No hallucinated features or capabilities
- [ ] Sources are verifiable — URLs resolve, docs exist
