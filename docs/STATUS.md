# Status

Living snapshot. Last updated: 2026-09-03. If this disagrees with code, fix this file in the same change.

## Phase

**Phase 0 — Foundation.** Docs, rules, repo layout exist. No launcher or runtime code yet. No local GPTK/CrossOver comparison logged.

## Hardware

- Target: Apple Silicon. Original plan assumed M3; use whatever M-series Mac this repo is on.
- OS: record `sw_vers` here after first setup. (This machine reported Darwin 25.x in the first session — likely macOS 26, not 27. Install the newest GPTK **that supports this OS**, not blindly GPTK 4 if it requires macOS 27.)

## Decisions

| ID | Topic | State |
| --- | --- | --- |
| ADR-000 | Wrap, don't write a translation layer | accepted |
| ADR-001 | Monorepo | accepted |
| ADR-002 | Ship Wine/OEM, eval GPTK | proposed (legal block on distribution only) |
| ADR-003 | Smoke + Spider-Man ladder | accepted |
| ADR-004 | No Wine in the UI | accepted |
| ADR-005 | Not Elden Ring | accepted |
| Decision 1 | GPTK vs CrossOver vs Wine as *dev* backend | **open** — needs hands-on |
| Smoke title | Aperture Desk Job default | **confirm after first boot** |

## Titles

| Role | Title | State |
| --- | --- | --- |
| Smoke | Aperture Desk Job (`1902490`) | profile stub only |
| Primary | Spider-Man Remastered (`1817070`) | profile stub only |
| #2 | TBD | not picked |

## Benchmarks

None. Do not claim performance.

## Blockers

1. Install GPTK + CrossOver; boot Steam-for-Windows or the smoke title in both.
2. Read GPTK license from the Apple download; paste a 5-line summary into ADR-002 when done.
3. Confirm smoke title (or swap to another free game from `GAMES.md`).
