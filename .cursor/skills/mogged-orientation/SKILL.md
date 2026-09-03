---
name: mogged-orientation
description: Loads Mogged product context, proof ladder, and source-of-truth docs. Use at the start of non-trivial work, when the user asks what Mogged is, or when planning runtime, launcher, or title work.
---

# Mogged orientation

Before coding, read (in order, stop if the task is tiny):

1. `/AGENTS.md`
2. `/docs/STATUS.md`
3. Task-specific: `/docs/GAMES.md`, `/docs/ARCHITECTURE.md`, `/docs/LEGAL.md`, `/docs/TELEMETRY.md`

## Reminders

- Product: Play on Mac. No user-facing Wine/GPTK.
- Wrap a translation stack. Do not write one.
- GPTK = local eval. Ship = Wine or CrossOver OEM (`docs/LEGAL.md`).
- Smoke = free Steam game (Aperture Desk Job unless STATUS says otherwise). Demo = Spider-Man Remastered. Not Elden Ring.
- Game knobs go in `profiles/*.json`.
- After a decision or phase gate, update `docs/STATUS.md` and `docs/DECISIONS.md`.

If the user asks to "just add GPTK to the app," refuse and point at LEGAL.md.
