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
│  spawn · prefix · caches · crash wrap       │
│  Optimization layer (ours): FPS cap from    │
│  thermal state, FSR, RT off, shader cache   │
└──────────────────┬──────────────────────────┘
                   │ composed OSS translation
┌──────────────────▼──────────────────────────┐
│  Game execution (not the product)           │
│  Wine → DXVK / vkd3d-proton → MoltenVK      │
│  Metal on this Apple Silicon Mac            │
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
- **Optimization layer** (`OptimizationLayer.swift`) is the product differentiator: look expensive, stay smooth, keep this Mac cool. Translation is composed OSS, not a from-scratch D3D writer.

## Decision 1 (accepted): free OSS stack

Zero paid software. See [BUILD.md](BUILD.md) and ADR-002.

| Component | Role | Ship inside Mogged.app? |
| --- | --- | --- |
| Wine (LGPL) | Win32 API / PE loader | Yes — with LGPL compliance |
| DXVK-macOS | D3D10/11 → Vulkan (macOS fork) | Yes |
| vkd3d-proton | D3D12 → Vulkan | Yes — with LGPL compliance |
| MoltenVK | Vulkan → Metal | Yes |
| Optimization layer (ours) | FPS cap, FSR, RT off, thermal | Yes |

GPTK and CrossOver are not part of the product and are not installed for this build.

## Graphics (where performance lives)

Spider-Man Remastered is **Direct3D 12**. DXVK does not translate D3D12.

1. **vkd3d-proton → Vulkan → MoltenVK → Metal** — shipping D3D12 path.
2. **DXVK-macOS → MoltenVK** — D3D10/11 titles (Apex).
3. **MoltenVK** — native Vulkan titles.

NVIDIA DLSS will not exist on this Mac. The **optimization layer** (`OptimizationLayer.swift`) is what we own: thermal → `DXVK_FRAME_RATE`, FSR Quality instead of native 4K, ray tracing off, shader cache on. Smooth and cool on this chassis is the v1 bar (ADR-011). Max RT + native 4K that melts the Mac is a fail.

v1 executes **on this Mac**. No cloud. We compose Wine/DXVK/MoltenVK; we do not write ntdll or D3D (ADR-000).

## What our code is allowed to do

- Detect installs (Steam libraries, exe hints, folder picker).
- Map AppID / exe → profile.
- Set env, upscaler, MetalFX, HUD toggles.
- Pre-warm shader / PSO caches.
- Capture FPS, frame times, input timestamps, crashes.
- Controller mapping.
- Cap FPS from thermal state so the chassis does not cook.

## What our code is not allowed to do

- Reimplement Windows/DirectX.
- Show a Windows-version picker or toolkit control panel.
- Depend on the user running third-party config utilities.
- Present Mogged as a frontend for GPTK, CrossOver, or any similarly named stack.
