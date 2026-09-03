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
│  Wine → DXVK / vkd3d-proton → MoltenVK      │
│  Metal on Apple Silicon                     │
└─────────────────────────────────────────────┘
```

Per-title JSON in `profiles/` is the contract. Game-specific flags belong there, not in Swift `if title == …`.

## Desktop app

- Swift + SwiftUI, Apple Silicon.
- Play / Stop. Library comes from the Steam client on this Mac. Mogged UI, not Steam chrome.
- Looks like a game launcher, not like developer tooling.
- Talks to `runtime/` over a local API (CLI is fine; XPC later). No cloud.

## Hidden runtime

- Spawns the Windows game, applies profile env/args, persists shader/PSO caches, collects logs.
- One isolated game environment per title (shared Steam library allowed if needed). The user never names or configures it.
- Backend is **injected by config** (`dxvk-moltenvk` | `vkd3d-moltenvk` | `moltenvk`). Wine path lives in `backend.json`, written on first run. The app does not hardcode a vendor toolkit path.

## Decision 1 (accepted): free OSS stack

Zero paid software. See [BUILD.md](BUILD.md) and ADR-002.

| Component | Role | Ship inside Mogged.app? |
| --- | --- | --- |
| Wine (LGPL) | Win32 API / PE loader | Yes — with LGPL compliance |
| DXVK | D3D9/10/11 → Vulkan | Yes |
| vkd3d-proton | D3D12 → Vulkan | Yes — with LGPL compliance |
| MoltenVK | Vulkan → Metal | Yes |

GPTK and CrossOver are not part of the product and are not installed for this build.

## Graphics (where performance lives)

Spider-Man Remastered is **Direct3D 12**. DXVK does not translate D3D12.

1. **vkd3d-proton → Vulkan → MoltenVK → Metal** — shipping D3D12 path.
2. **DXVK → MoltenVK** — D3D9/11 titles.
3. **MoltenVK** — native Vulkan titles (smoke).

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
