# Status

Living snapshot. Last updated: 2026-09-05. If this disagrees with code, fix this file in the same change.

Plan: [MILESTONES.md](MILESTONES.md). Build: [BUILD.md](BUILD.md). Branches: [BRANCHING.md](BRANCHING.md).

## Current milestone

**M0 — Foundation** (in progress), **M1 started** (Play now calls real spawn).

Done:

- Repo, docs, rules, profiles.
- Desktop-app identity (ADR-006).
- `dev` / `main` workflow.
- Native SwiftUI **operator** console: Install, Play, Stop, Locate, live %, **errors / events / title logs in-app** (copy, persist last error). First title = Aperture Desk Job.
- Runtime tests cover profile decode, user-facing copy, install lookup, launch/stop through a fake Wine, and thermal FPS caps.
- `RuntimeSupervisor.launch` creates a per-title environment, execs Wine, tracks PID, writes JSONL, Stop kills the process.
- Optimization layer: thermal → FPS cap (60/40/30), FSR Quality, RT off (ADR-011). v1 is **this Mac**.
- Translation engine is on disk and probed: Gcenx Wine Staging **11.16** ran `cmd.exe` (`mogged-ok`). MoltenVK sees **Apple M4 Pro**. DXVK-macOS `d3d11.dll` + `d3d10core.dll` in `third_party/dxvk/x64`.
- **Aperture Desk Job boots and draws.** 2026-09-05: `launch.exited code=0` after ~47s. DXVK 1.10.3 created a D3D11 device on M4 Pro; MoltenVK made a 1800×1169 `CAMetalLayer` swapchain. Path to that: DXVK staged in `engine/dxvk` and copied into the prefix, `game` as working directory with `-game steampal`, generated `steam.inf`, and Wine’s MoltenVK **JSON ICD** (a raw dylib in `VK_ICD_FILENAMES` lost `VK_KHR_surface` → exit 5).
- **Desk Job runs in a real Mac window with traffic lights.** 2026-09-05, captured from the live window: framed 1024×800 window, in-game overlay reporting **60.0 FPS**, GPU 53%, 1836 MB vidmem. Not a benchmark file yet, so it is not the quality bar. Window size and mode are `launch.window` in the profile (ADR-014); Source 2 needs `-width`/`-height`, it ignores `-w`/`-h` and falls back to 1024×768.
- Steam signs in from the command line before the game starts (ADR-015). Steam's own window paints black on this stack and its `-cef-*` flags never reach Chromium, so it stays hidden.

Not done:

- **Steam Input is still not initialized.** Desk Job shows "Unable to initialize Steam Input" over the rendered scene and will not go past it. Measured 2026-09-05: the client's first `-login` on a fresh prefix comes back **"Account Logon Denied"** — SteamCMD's device trust (used for Install) does not carry over to the graphical client, which wants its own one-time code. Mogged now reads the client's own log to notice this instead of retrying the same denied login forever, and reuses the account's existing "code" field to ask for it (ADR-015 update). Getting an actual code into that field and confirming Steam Input comes up is untested end to end.
- No benchmark file yet. The 60 FPS above is the game's own overlay on a title screen, not `tools/benchmark` output, and not the quality bar.
- Homebrew `wine-stable` and `gstreamer-runtime` casks are Gatekeeper-disabled (2026-09-01). GStreamer.framework is **not** installed; Wine still ran `cmd.exe`.
- vkd3d-proton DLLs not installed (Marvel Rivals D3D12).

## Hardware

- Chip: Apple M4 Pro
- OS: macOS 26.5.2 (25F84), arm64
- Xcode 26.4.1, Swift 6.3.1
- Unified memory seen by MoltenVK: ~18 GB GPU-available

## On-device stack (this Mac)

| Piece | Version / path | State |
| --- | --- | --- |
| Wine | Staging 11.16 (Gcenx), x86_64 via Rosetta | **runs Windows PE** (`cmd.exe`) |
| MoltenVK | Homebrew 1.4.2; Wine also bundled 1.4.0 | present, enumerated M4 Pro |
| DXVK-macOS | v1.10.3-20230507-repack (`d3d11`, `d3d10core` only) | DLLs on disk, not game-tested |
| vkd3d-proton | — | missing |
| GStreamer.framework | — | missing (cask Gatekeeper-disabled) |
| Optimization layer | `OptimizationLayer.swift` | wired into launch env |

Wine binary: `~/Library/Application Support/Mogged/engine/Wine Staging.app/Contents/Resources/wine/bin/wine`

`mogged-runtime detect` → that path.

macOS 26 showed **Support Ending for Intel-based Apps** on `Wine Staging.app`. Expected: Gcenx builds are x86_64 (`--build=x86_64-apple-darwin`). They run on this M4 Pro via Rosetta 2. Apple: Rosetta stays through **macOS 27**; starting **macOS 28** it is gone except for a narrow old-game carve-out. There is **no** Gcenx/WineHQ Apple silicon Wine tarball to “update” to. Native arm64 Wine on Darwin is still research. Apex / Rivals are Intel Windows EXEs anyway — even a native Wine host would still need CPU emulation for those games. Do not treat this banner as a blocker for v1 on macOS 26.

## Decisions

| ID | Topic | State |
| --- | --- | --- |
| ADR-013 | Steam runs in the title environment for SteamAPI / Steam Input | accepted |
| ADR-012 | First boot = Aperture Desk Job (safe, ~3 GB) | accepted |
| ADR-011 | v1 on this Mac; optimization layer is ours | accepted |
| ADR-010 | Founder targets = Apex + Rivals (AC expected to block online) | accepted |
| ADR-009 | Operator UI shows the stack | accepted |
| ADR-008 | Library = local Steam, Mogged UI | accepted |
| ADR-007 | `dev` vs `main` | accepted |
| ADR-006 | Native desktop app, not a compatibility GUI | accepted |
| ADR-005 | Not Elden Ring | accepted |
| ADR-004 | No toolkit names in the UI | accepted |
| ADR-003 | Smoke + Spider-Man ladder | accepted |
| ADR-002 | Shipping runtime = OSS Wine stack | accepted |
| ADR-001 | Monorepo | accepted |
| ADR-000 | Do not write a Windows/DX translator | accepted |
| Decision 1 | Wine + DXVK/vkd3d + MoltenVK | **accepted** |
| Smoke title | Aperture Desk Job, then Apex, then Rivals | **safe boot first (ADR-012)** |

## Titles

| Role | Title | State |
| --- | --- | --- |
| First (safe) | Aperture Desk Job (`1902490`) | **smoke**; installed; **boots and draws**; Steam Input pending |
| Next | Apex Legends (`1172470`) | pinned; heavy; not on disk |
| Then | Marvel Rivals (`2767030`) | pinned; heavy; not on disk |
| Later | Spider-Man Remastered (`1817070`) | profile exists; **not in the library until M2 / Steam has it** |

## Safety (this Mac)

Install writes only under `~/Library/Application Support/Mogged/games/<id>/`. No admin, no kernel extension, no SIP off. FPS caps if the chassis gets hot. Install refuses if the Mac is critically hot or free space is below the title budget (Desk Job = 5 GB). Apex / Rivals are 90 GB budgets on purpose. Stop kills the process. This cannot brick the Mac. A crash is a log line, not a hardware event.

## Benchmarks

None. Do not claim performance. Native 4K + ray tracing + uncapped FPS will cook this laptop — the optimization layer exists so we do not do that.

## Next

1. Open Mogged. **Aperture Desk Job** is first. Steam user / password / Guard → **Install** (~3 GB).
2. **Play**. This is the safe stack proof. Then Apex / Rivals.
3. Record what booted. Do not Install Apex until Desk Job has shown a window.
