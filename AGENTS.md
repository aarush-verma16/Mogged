# Agent instructions

Read this file before changing anything. Then read the docs listed for the task. Do not improvise a different product.

## What Mogged is

A dedicated Mac app. User clicks Play. A Windows PC game runs on Apple Silicon at near-native quality. **Zero user-facing Windows / Wine / bottle / prefix / GPTK / VM language.** Internal docs and logs may use those words. The app, screenshots, and demo copy may not.

## Source of truth

| Topic | File |
| --- | --- |
| Why this exists | [docs/VISION.md](docs/VISION.md) |
| Stack and layering | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| What we may ship | [docs/LEGAL.md](docs/LEGAL.md) |
| Which games, and why | [docs/GAMES.md](docs/GAMES.md) |
| What to build next | [docs/PHASES.md](docs/PHASES.md) |
| Locked vs open calls | [docs/DECISIONS.md](docs/DECISIONS.md) |
| Metrics | [docs/TELEMETRY.md](docs/TELEMETRY.md) |
| Where we actually are | [docs/STATUS.md](docs/STATUS.md) |
| Immediate work | [docs/WEEK-ONE.md](docs/WEEK-ONE.md) |
| Terms | [docs/GLOSSARY.md](docs/GLOSSARY.md) |

Update `docs/STATUS.md` and `docs/DECISIONS.md` when a phase exit criterion is hit or a Decision is made. Do not leave those files stale.

## Title ladder (locked)

- Smoke / plumbing: free Windows Steam game (default: Aperture Desk Job, Steam `1902490`).
- Primary demo: Marvel's Spider-Man Remastered (Steam `1817070`).
- Not MVP: Elden Ring, kernel anti-cheat titles, live-service shooters.

Game-specific knobs live in `profiles/*.json`, never hardcoded in the launcher.

## Engineering rules

1. **Wrap, don't rewrite.** Wine / CrossOver / D3DMetal / DXVK / MoltenVK are the translation stack. Our code is the supervisor, profiler, and UX.
2. **GPTK is eval-only.** Install it locally. Benchmark with it. Do not vendor, fork-and-ship, or bundle Apple's toolkit in the app until legal says otherwise. Shipping path is Wine (LGPL-compliant) or a licensed CrossOver/OEM arrangement.
3. **Invisible runtime.** Prefixes, bottles, winetricks, and env vars are implementation details. The user-facing verb is Play.
4. **Measure, don't vibe.** Any performance claim needs `tools/benchmark` output (FPS, frame-time percentile, hitch count). See `docs/TELEMETRY.md`.
5. **Speed over calendar.** Phase numbers are order, not weeks. Take the shortest path to the next proof.
6. **Stay in MVP scope.** No cloud, no store, no anti-cheat, no third title, no brand polish pass.

## Where to put new code

| Kind of change | Location |
| --- | --- |
| macOS UI, detection, Play button | `apps/launcher/` |
| Process spawn, prefix, env, Wine/GPTK glue | `runtime/` |
| Per-game flags and workarounds | `profiles/` |
| FPS / latency / crash capture | `tools/benchmark/` |
| One-off setup | `scripts/` |
| Strategy, ADRs, legal | `docs/` |

## Do not

- Mention Wine, GPTK, CrossOver, Proton, or bottles in user-visible strings.
- Add a game that fails `docs/GAMES.md` criteria without an ADR.
- Commit game binaries, Steam libraries, prefixes, GPTK DMGs, or shader caches.
- Treat a GPTK-only success as a shippable architecture.
