# Phases

Order of proofs. Not a calendar. Skip polish that does not unlock the next proof.

## Phase 0 — Foundation

**Exit:** Decision 1 (wrap GPTK vs CrossOver vs Wine) has a written recommendation in `DECISIONS.md`. Decision 2 is at least "eval now / ship later" with the GPTK license read. Smoke title is locked. Repo/docs/rules exist.

Work:

- Install GPTK and CrossOver on the Apple Silicon Mac. Get *any* Windows program booting in each.
- Run the same smoke title through both. Write numbers and notes in `docs/STATUS.md`.
- Read the GPTK license PDF/text from the Apple download. Do not rely on memory.
- Shortlist is already in `GAMES.md`; confirm the free Steam pick after the first boot.

This repo's docs and rules are Phase 0 product work. Runtime code starts the hour Decision 1 has a *leaning*, not after a 20-page memo.

## Phase 1 — It runs at all

**Exit:** A non-technical person can install Mogged, click Play on the smoke title, and reach gameplay without seeing the word Wine. Spider-Man Remastered at least reaches the main menu through the same shell (even if ugly).

Work:

- Hidden runtime supervisor (`runtime/`).
- Minimal Swift launcher (`apps/launcher/`): detect install, apply profile, Play.
- Prefix/bottle created automatically.
- Telemetry skeleton: FPS, frame-time log, crash capture — even if the HUD is developer-only.

Do not chase FPS here. Chase "no config file."

## Phase 2 — It runs well

**Exit:** Spider-Man Remastered hits the bar in `TELEMETRY.md` on the target Mac. We can record a side-by-side vs Windows that is a demo, not an apology.

Work:

- Shader / PSO precompile and persistent cache (Nixxes already ships a PSO cache — use it).
- Per-title profile: resolution, FSR/MetalFX, D3DMetal flags, RT off, DLSS ignored.
- Controller path measured end-to-end.
- `tools/benchmark` is rerunnable after every change.

## Phase 3 — The pipeline generalizes

**Exit:** Title #2 (different engine, different API) runs through profiles + detection with materially less manual work than Spider-Man took.

If title #2 takes as long as title #1, we have a one-off, not a platform. Write that down. It is still useful information.

Work:

- No hardcoded Spider-Man branches in the launcher.
- Scan install → match profile → apply.
- Pick title #2 to *break* the pipeline on purpose.

## Later (not MVP, not dated)

- Elden Ring as a public-demo / fundraising benchmark, gated on Phase 3.
- Store, cloud, anti-cheat, 50-title matrix, monetization.

## What not to build in any current phase

Remote/cloud compute. Support matrix. Kernel anti-cheat. Online multiplayer as a feature. Storefront. Library sync with Steam Cloud as a product. Custom UI brand system. A Wine GUI.
