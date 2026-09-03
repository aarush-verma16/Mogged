---
name: title-profile
description: Creates or updates a Mogged per-title JSON profile. Use when adding a game, changing launch flags, Steam AppIDs, graphics backends, or known issues for a title.
---

# Title profile

## Steps

1. Check `/docs/GAMES.md` criteria. Kernel anti-cheat or a Mac native build → stop and ADR.
2. Copy `/profiles/_schema.json` fields. Write `/profiles/<kebab-id>.json`.
3. Fill `steamAppId`, `executables`, `graphicsApi`, `antiCheat`, `backend.preferred`.
4. Put env vars and args in the profile, not in launcher source.
5. Link ProtonDB / CrossOver / GPTK notes under `research`.
6. If the title is not smoke or Spider-Man, add an ADR in `/docs/DECISIONS.md`.
7. Mention the new profile in `/docs/STATUS.md` if it changes the ladder.

## Roles

`smoke` | `primary-demo` | `generalize`

Spider-Man Remastered stays `primary-demo`. Do not add Elden Ring without explicitly moving it out of "not MVP."
