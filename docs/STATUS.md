# Status

Living snapshot. Last updated: 2026-09-03. If this disagrees with code, fix this file in the same change.

Plan: [MILESTONES.md](MILESTONES.md). Branches: [BRANCHING.md](BRANCHING.md).

## Current milestone

**M0 — Foundation** (in progress), **M1 started** (app shell exists).

Done:

- Repo, docs, rules, profiles.
- Desktop-app identity (ADR-006).
- `dev` / `main` workflow.
- Native SwiftUI app loads the library from profiles. Locate + Play call the hidden runtime.
- Runtime tests cover profile decode, user-facing copy, and install lookup.

Not done:

- No eval backend installed on this Mac (GPTK / CrossOver not present).
- Play still cannot spawn a Windows game (supervisor refuses until spawn is wired **and** a backend exists).
- GPTK license notes in ADR-002.
- Smoke title not booted yet.

## Hardware

- Chip: Apple M4 Pro
- OS: macOS 26.5.2 (25F84), arm64
- Xcode 26.4.1, Swift 6.3.1

## Decisions

| ID | Topic | State |
| --- | --- | --- |
| ADR-007 | `dev` vs `main` | accepted |
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
| Smoke | Aperture Desk Job (`1902490`) | in library UI; not launched |
| Primary | Spider-Man Remastered (`1817070`) | in library UI; not launched |
| #2 | TBD | not picked |

## Benchmarks

None. Do not claim performance.

## Next

1. Install GPTK and/or CrossOver locally (M0). Do not commit them.
2. Wire `RuntimeSupervisor.launch` to spawn through the detected backend.
3. Click Play on the smoke title from Mogged.app.
