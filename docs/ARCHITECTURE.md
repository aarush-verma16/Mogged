# Architecture

Mogged is three layers. Only the top one is allowed to be user-facing.

```
┌─────────────────────────────────────────────┐
│  Launcher (apps/launcher)                   │  ← user sees this
│  library scan · Play · status · logs (human)│
└──────────────────┬──────────────────────────┘
                   │ profile id + install path
┌──────────────────▼──────────────────────────┐
│  Runtime supervisor (runtime/)              │  ← invisible
│  prefix lifecycle · env · process · crash   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  Translation stack (not our code)           │
│  Wine or CrossOver                          │
│    ├─ D3DMetal (D3D11/12 → Metal)  preferred│
│    └─ DXVK + MoltenVK              fallback │
│  Metal / GPU on Apple Silicon               │
└─────────────────────────────────────────────┘
```

Per-title JSON in `profiles/` is the contract between launcher and runtime. If a flag is game-specific, it belongs in a profile, not in Swift.

## Decision 1 (open): which stack we wrap

Hands-on comparison is the first engineering work. Do not freeze a shipping stack from blog posts.

| Option | Role | Ship? |
| --- | --- | --- |
| **Apple GPTK** (D3DMetal + evaluation environment) | Fastest way to see if a title can run well on this Mac | **Eval only.** Apple's toolkit license is development/testing/non-commercial distribution. Do not bundle it. |
| **CrossOver** | Commercial Wine + D3DMetal integration, title workarounds | Ship only with a CodeWeavers license / OEM deal. Fine to install locally for benchmarks. |
| **Wine (upstream / wine-staging) + D3DMetal or DXVK/MoltenVK** | LGPL path we can actually redistribute if we comply | Default *candidate* for an independent product. |

Working rule until Decision 1 closes:

- Develop and benchmark against **GPTK and CrossOver on the machine**.
- Design our APIs as if the backend is a **replaceable Wine-class prefix + a graphics backend name** (`d3dmetal` | `dxvk-moltenvk`).
- Do not call GPTK binaries from the app in a way we could not swap for Wine.

Details and license constraints: [LEGAL.md](LEGAL.md). Record the call in [DECISIONS.md](DECISIONS.md).

## Graphics path (where performance lives)

Spider-Man Remastered is **Direct3D 12** (Nixxes PC port of the Insomniac engine). DXVK does not translate D3D12. The realistic paths are:

1. **D3DMetal** (GPTK / CrossOver) — D3D12 → Metal. This is the path to beat.
2. **vkd3d-proton → Vulkan → MoltenVK → Metal** — extra hops, usually worse. Fallback / experiment only.

D3D11 smoke titles can use DXVK→MoltenVK if D3DMetal misbehaves. Do not optimize the fallback before the preferred path is measured.

NVIDIA DLSS will not exist on this Mac. Profiles should prefer **FSR** in-game and/or **MetalFX** if we control the present path. Ray tracing is off for the MVP quality bar unless benchmarks say it is free.

## Process model

- One hidden prefix (or bottle) per title, created and updated by `runtime/`.
- Steam-for-Windows may live in a shared prefix if that is how the smoke title is installed; the user still never manages it.
- Launcher talks to runtime over a local API (CLI today is fine; XPC later if needed). No network protocol for MVP.
- The game process is a child we can kill, snapshot, and scrape for telemetry.

## What our code is allowed to do

- Detect installs (Steam `libraryfolders.vdf`, common Windows Steam paths inside the prefix, explicit folder picker).
- Map Steam AppID / exe name → profile.
- Set env, DLL overrides, DX/VK flags, MetalFX, HUD toggles.
- Pre-warm shader / PSO caches.
- Capture FPS, frame times, input timestamps, crash reports.
- Controller mapping.

## What our code is not allowed to do

- Reimplement ntdll, wineserver, or D3D.
- Show a "Windows version" picker.
- Depend on a human running `winecfg` or Winetricks.
