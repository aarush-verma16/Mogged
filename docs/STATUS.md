# Status

Living snapshot. Last updated: 2026-09-03. If this disagrees with code, fix this file in the same change.

Plan: [MILESTONES.md](MILESTONES.md). Build: [BUILD.md](BUILD.md). Branches: [BRANCHING.md](BRANCHING.md).

## Current milestone

**M0 — Foundation** (in progress), **M1 started** (Play now calls real spawn).

Done:

- Repo, docs, rules, profiles.
- Desktop-app identity (ADR-006).
- `dev` / `main` workflow.
- Native SwiftUI app loads the library from profiles. Locate + Play call the hidden runtime.
- Runtime tests cover profile decode, user-facing copy, install lookup, and launch/stop through a fake Wine.
- `RuntimeSupervisor.launch` creates a per-title environment, execs Wine, tracks PID, writes JSONL, Stop kills the process.
- Decision 1 accepted: free Wine + DXVK + vkd3d-proton + MoltenVK. No paid software.

Not done:

- Wine is **not installed** on this Mac yet. Run `npm run bootstrap`.
- Smoke title not installed / not booted.
- DXVK / vkd3d-proton / MoltenVK not vendored in `third_party/` yet.

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
| ADR-002 | Shipping runtime = OSS Wine stack | accepted |
| ADR-001 | Monorepo | accepted |
| ADR-000 | Do not write a Windows/DX translator | accepted |
| Decision 1 | Wine + DXVK/vkd3d + MoltenVK | **accepted** |
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

1. `npm run bootstrap` — Homebrew Wine + MoltenVK on this Mac (free).
2. Install the smoke title (Windows Steam build).
3. Click Play from Mogged.app. Record the first boot in this file.
