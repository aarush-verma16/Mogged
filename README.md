# Mogged

A Mac app that launches Windows PC games on Apple Silicon. Open the app, click Play, the game runs well. The player never sees Windows, Wine, bottles, or virtualization.

This repository is a **monorepo** for the MVP. The proof is not a compatibility database. The proof is one demanding title running at near-native quality through a product UX.

## Proof ladder

1. **Smoke (free Steam title)** — anything Windows boots from Mogged with no config file. Default candidate: *Aperture Desk Job*.
2. **Primary demo** — *Marvel's Spider-Man Remastered* running well (FPS, frame pacing, input latency).
3. **Generalization** — a second, different-engine title through the same profile pipeline, with less manual work than the first.

Elden Ring is **not** on the MVP path.

## What we build vs what we wrap

| Layer | Who owns it |
| --- | --- |
| Windows API / syscall translation | Wine (LGPL) or CrossOver. GPTK is for **evaluation only**. |
| DirectX → Metal | D3DMetal (preferred) or DXVK + MoltenVK |
| Product | Us: detection, per-title profiles, shader cache, input, telemetry, Play UX |

Do not write a translation layer. Wrap one, hide it, tune titles.

## Repo map

```
apps/launcher/     macOS app (Swift) — the only user-facing surface
runtime/           hidden translation-stack supervisor
profiles/          per-title JSON (flags, shaders, input, known issues)
tools/benchmark/   repeatable FPS / frametime / latency harness
docs/              source of truth for product, stack, legal, titles
```

Start here:

- Humans: [docs/VISION.md](docs/VISION.md), [docs/GAMES.md](docs/GAMES.md), [docs/PHASES.md](docs/PHASES.md)
- Agents: [AGENTS.md](AGENTS.md)
- This week's work: [docs/WEEK-ONE.md](docs/WEEK-ONE.md)
- Current snapshot: [docs/STATUS.md](docs/STATUS.md)

## Non-goals (MVP)

No cloud/remote rendering. No anti-cheat / online multiplayer. No store, library sync, or monetization. No support matrix beyond the proof ladder. UI only has to be functional and non-embarrassing.

## License

Our code is proprietary until we say otherwise. Wine, DXVK, MoltenVK, and Apple GPTK keep their own licenses — see [docs/LEGAL.md](docs/LEGAL.md). GPTK must not be redistributed inside the product.
