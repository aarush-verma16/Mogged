---
name: runtime-eval
description: Records the first Wine boot of the smoke title (M0). Use when installing the free stack or writing STATUS notes after Play.
---

# Runtime eval

Part of **M0** in `/docs/MILESTONES.md`. Free stack only. Do not commit installers, prefixes, or games.

```
npm run bootstrap
```

That installs Homebrew Wine + MoltenVK. Never CrossOver. Never GPTK.

## Output

Update `/docs/STATUS.md`:

| Backend | Title | Booted | Manual steps | Notes |
| --- | --- | --- | --- | --- |
| wine + dxvk | apex-legends | | | |

Decision 1 is already accepted (OSS Wine stack). Do not reopen it to add paid software.

## Hard rules

- Smoke title first. Not Spider-Man.
- Record Wine version and what broke.
- A Wine boot is evidence the hidden runtime works, not permission to show Wine in the UI.
