# Mogged

Native **macOS desktop app** for playing Windows PC games on Apple Silicon. Open Mogged, click Play, the game runs well.

This is not a compatibility manager, not a bottle GUI, and not a Wine/CrossOver frontend. The product is the app. How a Windows title is executed is a hidden runtime, not the identity of the company.

## Follow this

**[docs/MILESTONES.md](docs/MILESTONES.md)** — the only plan. Milestones have exit criteria. No weeks, no calendar.

**[docs/BUILD.md](docs/BUILD.md)** — free stack only (Wine + DXVK + vkd3d-proton + MoltenVK). Zero paid software.

Current snapshot: [docs/STATUS.md](docs/STATUS.md).

Proof titles: Apex Legends → Marvel Rivals → *Marvel's Spider-Man Remastered* later. Elden Ring is not MVP.

## Repo

```
apps/launcher/     native macOS desktop app (Swift) — what the user runs
runtime/           hidden game runtime (process, env, caches)
profiles/          per-title JSON
tools/benchmark/   FPS / frametime / latency harness
docs/              product + architecture + legal
```

Also: [docs/VISION.md](docs/VISION.md), [docs/GAMES.md](docs/GAMES.md), [docs/BRANCHING.md](docs/BRANCHING.md), [AGENTS.md](AGENTS.md).

## Run (dev)

```bash
git checkout dev
npm test
npm run bootstrap   # Gcenx Wine + MoltenVK + DXVK-macOS, once
STEAM_USER=you npm run fetch -- apex-legends   # Windows Apex files via SteamCMD (not the Mac Steam app)
npm start
```

`npm run dev` is the same as `npm start`. Work on `dev`. Freeze to `main` only when a milestone is snapshot-ready.

## Non-goals (MVP)

No cloud. No anti-cheat / online multiplayer. No store or monetization. No support matrix. UI: functional, not a brand system.

## License

Our app code is proprietary. Third-party runtimes and toolkits keep their own licenses — [docs/LEGAL.md](docs/LEGAL.md). Do not redistribute Apple's Game Porting Toolkit inside Mogged.
