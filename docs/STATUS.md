# Status

Living snapshot. Last updated: 2026-09-03. If this disagrees with code, fix this file in the same change.

Plan to follow: [MILESTONES.md](MILESTONES.md). There is no week-based schedule.

## Current milestone

**M0 — Foundation** (in progress)

Done: repo, docs, rules, profile stubs, desktop-app identity.

Not done: eval backends on this Mac, smoke title actually booting, GPTK license notes in ADR-002.

## Hardware

- Target: Apple Silicon. Use the M-series Mac this repo lives on.
- OS: record `sw_vers` here after first setup. (Darwin 25.x in the first session — likely macOS 26. Install the newest GPTK **that supports this OS**, not a release that requires a newer macOS.)

## Decisions

| ID | Topic | State |
| --- | --- | --- |
| ADR-006 | Native desktop app, not a compatibility GUI | accepted |
| ADR-005 | Not Elden Ring | accepted |
| ADR-004 | No toolkit names in the UI | accepted |
| ADR-003 | Smoke + Spider-Man ladder | accepted |
| ADR-002 | Shipping vs eval backends | proposed |
| ADR-001 | Monorepo | accepted |
| ADR-000 | Do not write a Windows/DX translator | accepted |
| Decision 1 | Which execution backend to call from runtime | **open** |
| Smoke title | Aperture Desk Job default | **confirm after first boot** |

## Titles

| Role | Title | State |
| --- | --- | --- |
| Smoke | Aperture Desk Job (`1902490`) | profile stub only |
| Primary | Spider-Man Remastered (`1817070`) | profile stub only |
| #2 | TBD | not picked |

## Benchmarks

None. Do not claim performance.

## Next (M0 leftovers)

1. Install GPTK + CrossOver locally; boot the smoke title (or Windows Steam) in both; table this file.
2. Read GPTK license from the Apple download; short summary into ADR-002.
3. Confirm or swap the smoke title via `GAMES.md`.
4. After a backend leaning: start `apps/launcher` (native Swift). That is M1, allowed to overlap once M0 eval has pixels.
