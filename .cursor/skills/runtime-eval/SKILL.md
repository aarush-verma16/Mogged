---
name: runtime-eval
description: Runs or records the GPTK vs CrossOver vs Wine comparison for Decision 1. Use when installing toolkits, booting a smoke title, or recommending which translation backend Mogged should wrap.
---

# Runtime eval

Follow `/docs/WEEK-ONE.md`. Do not commit installers, prefixes, or games.

## Output

Update `/docs/STATUS.md` with a table:

| Stack | Title | Booted | Manual steps | Rough FPS | Notes |
| --- | --- | --- | --- | --- | --- |

Then add or update ADR-002 / Decision 1 in `/docs/DECISIONS.md` with a **leaning** (eval backend vs ship backend).

## Hard rules

- Read the GPTK license from Apple's download, not from memory. Three sentences in the ADR.
- Treat GPTK success as evidence, not as a redistribution plan.
- Same title, same Mac, both stacks. No apples-to-oranges GPU presets.
- Spider-Man is not the first boot target. Smoke title first.
