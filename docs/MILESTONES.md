# Milestones

This is the plan. No dates, no weeks, no phases-as-calendar. Work the current milestone until its **exit criteria** are all true, then move on. Skip anything that does not unlock the next exit.

Track progress in [STATUS.md](STATUS.md). When a milestone completes, check it off here and there.

| ID | Milestone | Status |
| --- | --- | --- |
| **M0** | Machine can run a Windows game; Mogged is defined as a desktop app | **current** |
| **M1** | Mogged.app: click Play, smoke title runs | **started** (app + runtime; launch not live) |
| **M2** | Spider-Man Remastered reaches gameplay through Mogged | not started |
| **M3** | Spider-Man hits the quality bar | not started |
| **M4** | A second, different-engine title uses the same pipeline | not started |
| — | Elden Ring, store, cloud, anti-cheat | not MVP |

---

## M0 — Foundation

**Exit (all of these):**

- [x] Repo, docs, rules, and title profiles exist.
- [x] Native Mac app identity is the product (not a compatibility GUI). Locked in ADRs.
- [x] Apple Silicon Mac recorded in STATUS (`sw_vers`, chip).
- [ ] Wine (free, LGPL) runs a Windows `.exe` on this Mac — via Homebrew or Whisky's open-source build.
- [ ] DXVK + MoltenVK path tested: smoke title (Aperture Desk Job or a free Steam Windows game) reaches pixels.
- [ ] Notes in STATUS: Wine version, DXVK version, what ran, what broke.
- [ ] No paid software used at any point. No CrossOver. No GPTK.
- [ ] Smoke title confirmed or swapped using [GAMES.md](GAMES.md).

**Work:** Homebrew install Wine + DXVK. Run the smoke title manually. Record what worked. Start wiring `runtime/` as soon as the free stack boots anything.

**Not this milestone:** FPS targets, Spider-Man, UI polish, shipping to anyone.

**Stack (all free):** Wine (LGPL) → DXVK/vkd3d-proton → MoltenVK → Metal. See [BUILD.md](BUILD.md) for the full breakdown.

---

## M1 — First Play

**Exit (all of these):**

- [x] `apps/launcher` is a native macOS desktop app (Swift). Play / Stop. No compatibility-manager screens.
- [ ] Hidden `runtime/` creates whatever it needs and launches the smoke title. The user never touches a config file.
- [ ] A non-technical person can open Mogged, click Play, and get into the smoke title.
- [ ] Crash/FPS logging exists even if it is developer-only ([TELEMETRY.md](TELEMETRY.md)).

**Work:** Desktop app shell, install detection, profile apply, one-click launch. Hide the engine. Do not chase frame rate.

**Not this milestone:** Store, accounts, bottle UI, Wine/GPTK copy, Spider-Man quality.

---

## M2 — Spider-Man boots

**Exit (all of these):**

- [ ] Marvel's Spider-Man Remastered launches from the same Play button as the smoke title.
- [ ] Reaches main menu, then actual gameplay, with no manual config.
- [ ] Profile in `profiles/spider-man-remastered.json` is what the runtime uses (no hardcoded title branch required to boot).

**Work:** D3D12 path (D3DMetal preferred), SteamDeck=0, RT off, ignore DLSS. Get into the city. Ugly is fine.

**Not this milestone:** Near-native FPS, side-by-side video, second commercial title.

---

## M3 — Spider-Man runs well

**Exit (all of these):**

- [ ] Repeatable `tools/benchmark` run for the profile's route.
- [ ] Numbers meet the bar in [TELEMETRY.md](TELEMETRY.md) on the demo Mac.
- [ ] Warm-cache launch does not hitch like a first shader compile.
- [ ] Controller and KBM latency checked, not just "it maps."
- [ ] Side-by-side vs Windows at a comparable preset (FSR/MetalFX vs DLSS) is a credible demo.

**Work:** PSO/shader cache (Nixxes ships a cache — use it), resolution/upscaler profile, MetalFX/FSR, input path, harness after every change.

**Not this milestone:** Title #2, Elden Ring, marketing site.

---

## M4 — Pipeline, not a one-off

**Exit (all of these):**

- [ ] Title #2 is picked (different engine **and** different graphics API than Spider-Man). ADR written.
- [ ] Same detection → profile → Play path. Materially less hand-holding than M2+M3.
- [ ] No Spider-Man-only branches in the launcher. New flags go in schema + profile JSON.

If title #2 takes as long as Spider-Man, we have a one-off. Write that in STATUS. That is still a result.

**Not this milestone:** Support matrix, anti-cheat titles, store.

---

## Not MVP (no milestone, no date)

Elden Ring as a later public-demo benchmark (gate on M4). Cloud/remote rendering. Store. Library sync. Monetization. Kernel anti-cheat. Online multiplayer as a feature. Brand polish beyond functional. A compatibility-layer control panel.

## Rule

Do not start the next milestone's *optional* polish before the current exit criteria are true. Starting the Swift app during M0 is allowed. Shipping M3 video during M1 is not.
