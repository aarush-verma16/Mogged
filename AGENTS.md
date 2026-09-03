# Agent instructions

Read this file before changing anything. Then read the docs for the task. Do not improvise a different product.

## What Mogged is

A **native macOS desktop app** (Swift). The user clicks Play. A Windows PC game runs on Apple Silicon at near-native quality.

Mogged is the product. It is not a Wine app, not a GPTK wrapper with a coat of paint, not a bottle manager. User-visible copy, screenshots, and demo talk never mention Windows internals, Wine, GPTK, Proton, bottles, prefixes, or VMs.

## Source of truth

| Topic | File |
| --- | --- |
| Why this exists | [docs/VISION.md](docs/VISION.md) |
| **What to do next** | [docs/MILESTONES.md](docs/MILESTONES.md) |
| How we build the stack | [docs/BUILD.md](docs/BUILD.md) |
| Where we are | [docs/STATUS.md](docs/STATUS.md) |
| Git branches | [docs/BRANCHING.md](docs/BRANCHING.md) |
| Stack | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| What we may ship | [docs/LEGAL.md](docs/LEGAL.md) |
| Titles | [docs/GAMES.md](docs/GAMES.md) |
| ADRs | [docs/DECISIONS.md](docs/DECISIONS.md) |
| Metrics | [docs/TELEMETRY.md](docs/TELEMETRY.md) |
| Terms | [docs/GLOSSARY.md](docs/GLOSSARY.md) |

When a milestone exit is hit or a Decision is made, update `docs/STATUS.md`, `docs/MILESTONES.md`, and `docs/DECISIONS.md` in the same change.

There is no week-based plan. Do not add one.

## Title ladder (locked)

- Smoke: Apex Legends (`1172470`), then Marvel Rivals (`2767030`). Anti-cheat will likely block online. [docs/GAMES.md](docs/GAMES.md).
- Primary demo: Marvel's Spider-Man Remastered (`1817070`).
- Not MVP: Elden Ring, kernel anti-cheat, live-service shooters.

Knobs live in `profiles/*.json`, never hardcoded in the launcher.

## Engineering rules

1. **Desktop app first.** All user-facing work lives in `apps/launcher/` as a real Mac app.
2. **Hidden runtime.** `runtime/` may spawn an eval/shipping backend. The app never looks like a toolkit.
3. **Do not write a Windows/DirectX translator.** Embed or call a backend; concentrate on detection, profiles, caches, input, telemetry, Play.
4. **Zero paid software.** Wine + DXVK + vkd3d-proton + MoltenVK. Do not buy CrossOver. Do not install GPTK. [docs/BUILD.md](docs/BUILD.md), [docs/LEGAL.md](docs/LEGAL.md).
5. **Measure.** Performance claims need `tools/benchmark` output ([docs/TELEMETRY.md](docs/TELEMETRY.md)).
6. **Current milestone only.** Finish exit criteria in `docs/MILESTONES.md` before optional work on the next one.
7. **MVP scope.** No cloud, store, anti-cheat, third title, or brand system.
8. **`dev` is HEAD.** Commit and PR to `dev`. Do not commit to `main` unless asked to freeze. [docs/BRANCHING.md](docs/BRANCHING.md).

## Where to put new code

| Kind of change | Location |
| --- | --- |
| macOS UI, detection, Play | `apps/launcher/` |
| Process spawn, env, engine glue | `runtime/` |
| Per-game flags | `profiles/` |
| FPS / latency / crash capture | `tools/benchmark/` |
| One-off setup | `scripts/` |
| Strategy, ADRs, legal | `docs/` |

## Do not

- Mention Wine, GPTK, CrossOver, Proton, or bottles in user-visible strings.
- Add a game that fails `docs/GAMES.md` without an ADR.
- Commit game binaries, Steam libraries, prefixes, GPTK DMGs, or shader caches.
- Treat a GPTK-only success as a shippable architecture.
- Reintroduce week numbers or calendars into the plan.
