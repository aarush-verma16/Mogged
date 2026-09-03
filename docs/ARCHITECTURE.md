# Architecture

Mogged is a **native macOS desktop application**. Only that process is user-facing.

```
┌─────────────────────────────────────────────┐
│  Mogged.app  (apps/launcher, Swift)         │  ← the product
│  library · Play / Stop · human status       │
└──────────────────┬──────────────────────────┘
                   │ profile id + install path
┌──────────────────▼──────────────────────────┐
│  Runtime  (runtime/)                        │  ← invisible
│  env · process · caches · crash wrap        │
└──────────────────┬──────────────────────────┘
                   │ swappable backend
┌──────────────────▼──────────────────────────┐
│  Game execution (not the product)           │
│  DirectX → Metal (D3DMetal preferred)       │
│  Metal on Apple Silicon                     │
└─────────────────────────────────────────────┘
```

Per-title JSON in `profiles/` is the contract. Game-specific flags belong there, not in Swift `if title == …`.

## Desktop app

- Swift + SwiftUI, Apple Silicon.
- Play / Stop. Library of titles we detected.
- Looks like a game launcher, not like developer tooling.
- Talks to `runtime/` over a local API (CLI is fine; XPC later). No cloud.

## Hidden runtime

- Spawns the Windows game, applies profile env/args, persists shader/PSO caches, collects logs.
- One isolated game environment per title (shared Steam library allowed if needed). The user never names or configures it.
- Backend is **injected by config** (`d3dmetal` | `dxvk-moltenvk` | `moltenvk` | `vkd3d-moltenvk`). The app does not hardcode a vendor toolkit path.

## Decision 1 (open): which execution backend

We evaluate locally so Spider-Man can actually start. That is not the same as "Mogged is built on X."

| Local eval | Why we touch it | Ship inside Mogged.app? |
| --- | --- | --- |
| Apple GPTK (D3DMetal) | Fastest check that a title can run well on this Mac | **No** — eval/dev license. See [LEGAL.md](LEGAL.md). |
| CrossOver | Commercial D3DMetal stack, title workarounds | Only with an OEM/license deal. |
| Other D3DMetal / DX→Metal engines | Possible shipping path | Only with a license we can redistribute. |

Until Decision 1 closes:

- Benchmark GPTK and CrossOver **on the machine** (M0).
- Design launcher ↔ runtime as if the backend is replaceable.
- Do not build UI around a specific toolkit.
- Do not vendor GPTK.

Record the call in [DECISIONS.md](DECISIONS.md). Milestone sequence: [MILESTONES.md](MILESTONES.md).

## Graphics (where performance lives)

Spider-Man Remastered is **Direct3D 12**. DXVK does not translate D3D12.

1. **D3DMetal** — D3D12 → Metal. Path to beat.
2. **vkd3d-proton → Vulkan → MoltenVK → Metal** — extra hops. Fallback only.

NVIDIA DLSS will not exist on this Mac. Prefer **FSR** in-game and/or **MetalFX**. Ray tracing off for the MVP bar unless a benchmark says it is free.

## What our code is allowed to do

- Detect installs (Steam libraries, exe hints, folder picker).
- Map AppID / exe → profile.
- Set env, upscaler, MetalFX, HUD toggles.
- Pre-warm shader / PSO caches.
- Capture FPS, frame times, input timestamps, crashes.
- Controller mapping.

## What our code is not allowed to do

- Reimplement Windows/DirectX.
- Show a Windows-version picker or toolkit control panel.
- Depend on the user running third-party config utilities.
- Present Mogged as a frontend for GPTK, CrossOver, or any similarly named stack.
