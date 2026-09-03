# Titles

Selection is a product decision, not a Steam sale decision. A title that needs kernel anti-cheat or a Mac native build does not prove Mogged.

## Criteria (every title)

Must satisfy all of:

1. **No kernel-level anti-cheat** (Easy Anti-Cheat, BattlEye, Vanguard, etc.). Steam VAC-only is still discouraged for the smoke title.
2. **No macOS native build** we could accidentally launch instead of the Windows build.
3. **Offline or single-player capable.**
4. **DirectX 11 or 12 preferred** for anything that is supposed to predict Spider-Man. Vulkan/Source 2 is acceptable only as *plumbing* smoke.
5. **Already known to run** in CrossOver and/or GPTK community reports — we optimize, we do not debug a broken title from zero.

## Ladder

| Stage | Title | Steam AppID | Why |
| --- | --- | --- | --- |
| Smoke (free) | **Aperture Desk Job** (default) | `1902490` | Free, small, Valve, no AC, Windows/Linux only, no Mac native. Proves: prefix + Steam + Play. **Does not prove D3D12** (Source 2 / Vulkan). |
| DX smoke (free, optional) | Path of Exile or Dota 2 | `238960` / `570` | Free DirectX-class GPU load before buying Spider-Man. PoE: DX11, no kernel AC. Dota 2: commonly used in GPTK benches; VAC; heavier. |
| **Primary demo** | **Marvel's Spider-Man Remastered** | `1817070` | The actual proof. DX12, Insomniac/Nixxes, no AC, ProtonDB Platinum, CrossOver-playable, real GPU cost, FSR available (DLSS will not translate). |
| Generalize | TBD in Phase 3 | — | Different engine **and** different API than Spider-Man. Pick after Phase 2 numbers exist. |
| Explicitly not MVP | Elden Ring, Nightreign, competitive shooters | — | Heavier FromSoftware quirks, EAC in some modes. Public-demo bait, not the first proof. |

Change the smoke title if needed; **do not change the primary demo** without an ADR. Profiles live in `/profiles`.

## Smoke shortlist (pick one this week)

Ranked for *small tests before Spider-Man*:

1. **Aperture Desk Job** (`1902490`) — smallest honest "Windows game on Steam." Needs a controller. Graphics path ≠ Spider-Man.
2. **osu!** (`776387`) — tiny download, D3D/GL, no AC. Almost too light; good for "did Wine start."
3. **Alien Swarm: Reactive Drop** (`563560`) — free Source/DX9 shooter, no kernel AC. Tests older D3D, not D3D12.
4. **Path of Exile** (`238960`) — free, DX11, real load, large download. Best *free* predictor of translation-layer pain besides Spider-Man.
5. **Dota 2** (`570`) — free, Source 2, used in published GPTK/CrossOver benches. VAC + live service; use only if we need a GPTK-comparison datapoint.

Default in profiles and docs: **Aperture Desk Job**. If the first GPTK/CrossOver boot is too easy and teaches us nothing about D3D, add Path of Exile next — still free, still before buying Spider-Man.

## Primary: Spider-Man Remastered

| Field | Value |
| --- | --- |
| Engine | Insomniac, PC port by Nixxes |
| API | Direct3D 12 (not 11) |
| Anti-cheat | None |
| Upscaling | DLSS (NVIDIA, ignore), FSR 2 (use), MetalFX (explore) |
| Ray tracing | Supported; **off** for MVP bar |
| Shaders | Nixxes ships a PSO cache beside the game — steal this idea, do not ignore it |
| Input | KBM + DualSense; verify latency, not just mapping |
| Known Mac-class issues | Cutscene / silent crashes in CrossOver reports; RT/VRAM false positives when `SteamDeck=1`; DLSS missing |

Success is not "it opened." Success is a repeatable benchmark vs a Windows PC at a comparable quality preset (FSR/MetalFX standing in for DLSS). Numbers: [TELEMETRY.md](TELEMETRY.md).

## Adding a title

1. Check criteria above.
2. Add `profiles/<id>.json` from `_schema.json`.
3. Note ProtonDB + CrossOver + GPTK links in the profile `research` block.
4. If it is not smoke/Spider-Man, write an ADR.

Do not keep a living 200-game spreadsheet. Two titles plus one smoke is the MVP.
