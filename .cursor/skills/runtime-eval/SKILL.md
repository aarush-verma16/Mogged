---
name: runtime-eval
description: Records local GPTK vs CrossOver eval for Decision 1 (M0). Use when installing test harnesses, booting the smoke title, or recommending which execution backend the hidden runtime should call.
---

# Runtime eval

Part of **M0** in `/docs/MILESTONES.md`. Do not commit installers, prefixes, or games. This eval is not the product.

## Output

Update `/docs/STATUS.md`:

| Backend | Title | Booted | Manual steps | Rough FPS | Notes |
| --- | --- | --- | --- | --- | --- |

Then update ADR-002 / Decision 1 in `/docs/DECISIONS.md` (eval harness vs what we might legally embed later).

## Hard rules

- Read the GPTK license from Apple's download. Three sentences in the ADR.
- GPTK success is evidence a title can run, not permission to ship GPTK.
- Same title, same Mac, both harnesses.
- Smoke title first. Not Spider-Man.
