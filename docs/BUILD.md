# Build Plan

> **Constraint: zero paid software.** We do not buy CrossOver. We do not require GPTK. Every component in the execution stack is free and open-source or ships free with macOS/Xcode. This file is the authoritative guide for what we actually build and in what order.

---

## The stack we use (all free)

| Layer | What | License | Ships inside Mogged? |
| --- | --- | --- | --- |
| Mac app | Swift + SwiftUI | Apple / Xcode (free) | Yes — it is the product |
| Runtime supervisor | Our Swift code | Proprietary (ours) | Yes |
| Windows API translation | **Wine** (LGPL build) | LGPL | Yes — with LGPL compliance |
| DirectX 9/10/11 → Vulkan | **DXVK** | zlib | Yes |
| DirectX 12 → Vulkan | **vkd3d-proton** | LGPL | Yes |
| Vulkan → Metal | **MoltenVK** | Apache 2.0 | Yes |
| GPU | Metal on Apple Silicon | Ships with macOS | Yes (system) |

That's the full pipeline. No CrossOver. No GPTK. No Windows license.

```
Windows game EXE
      ↓ Wine (Win32 API, PE loader)
      ↓ DXVK / vkd3d-proton (DirectX → Vulkan)
      ↓ MoltenVK (Vulkan → Metal)
      ↓ Metal on Apple Silicon (M-series GPU)
```

Mogged wraps this invisibly. The user clicks Play. The user never sees Wine, Vulkan, or Metal.

---

## What "ships inside Mogged" means

We vendor or submodule these libraries. They live in `third_party/`. We do not ask the user to install anything. We do not download anything at runtime. The `.app` bundle contains the stack.

LGPL compliance for Wine and vkd3d-proton: dynamic link (`.dylib`), keep notices, provide source pointer. See `docs/LEGAL.md`. This is solved — every macOS Wine port already ships this way.

---

## Milestones under this constraint

### M0 — Smoke title boots on this Mac (free stack only)

**Exit criteria:**

- [ ] Wine binary (from Homebrew or Whisky's open-source build) runs a Windows `.exe` on this Mac.
- [ ] DXVK + MoltenVK path tested with a DX11 title (Aperture Desk Job or similar free Steam Windows game).
- [ ] vkd3d-proton + MoltenVK path tested with a DX12 title if possible at this stage.
- [ ] Notes in `docs/STATUS.md`: which Wine version, which DXVK version, what launched, what broke.
- [ ] No paid software used at any point.

**How to test (dev machine only):**

```bash
# Install via Homebrew — free, open source
brew install --cask whisky          # Whisky is open-source (MIT); uses Wine under the hood
# OR install Wine directly:
brew install wine-crossover         # CodeWeavers' open patches, not the paid app
# Then point at a Windows Steam game EXE and run it
```

Whisky is the open-source macOS Wine frontend (MIT license). It is a reference, not the product. We use it to verify the free stack works before wiring it into Mogged.

**Not this milestone:** FPS targets, Spider-Man, Mogged UI polish, anything paid.

---

### M1 — Mogged.app: click Play, smoke title runs (free stack wired)

**Exit criteria:**

- [ ] `runtime/` builds and manages a Wine prefix silently (user never sees it).
- [ ] `RuntimeSupervisor.launch()` execs the game through Wine + DXVK + MoltenVK using the profile JSON.
- [ ] Play button in the Mac app actually starts the game. Stop kills it.
- [ ] No manual config by the user. No Wine dialog, no prefix path visible.
- [ ] Basic telemetry: one JSONL line per session (title, start time, exit code).

**Key files to build:**

| File | What it does |
| --- | --- |
| `runtime/Sources/MoggedRuntime/WineEnvironment.swift` | Creates and manages the Wine prefix directory |
| `runtime/Sources/MoggedRuntime/BackendLauncher.swift` | Builds the Wine exec command from profile + backend config |
| `runtime/Sources/MoggedRuntime/ProcessHandle.swift` | Spawns, monitors, kills the game process |
| `runtime/Sources/MoggedRuntime/RuntimeSupervisor.swift` | Wires the above, exposes `launch()` and `stop()` |
| `config/backend.json` (user's app support dir) | Points at Wine/DXVK binary paths — written by Mogged on first run |

**Backend config written on first run (hidden from user):**

```json
{
  "wine": "/usr/local/bin/wine64",
  "dxvk_path": "bundled",
  "vkd3d_path": "bundled",
  "molten_vk": "bundled"
}
```

The user never touches this. Mogged writes it. Mogged reads it. Swappable later.

---

### M2 — Spider-Man Remastered boots through Mogged

**Exit criteria:**

- [ ] Marvel's Spider-Man Remastered launches from the Play button.
- [ ] Gets to main menu → gameplay. No manual config.
- [ ] vkd3d-proton handles the DX12 path (not DXVK).
- [ ] Profile `profiles/spider-man-remastered.json` drives all flags. No title-specific Swift code.

**Expected hard parts:**

- vkd3d-proton + MoltenVK on DX12 is less tested than DXVK on DX11. Expect shader compiler errors.
- Nixxes (Spider-Man port studio) ships a PSO cache — use it.
- Ray tracing off, DLSS irrelevant (no NVIDIA), FSR on.

---

### M3 — Spider-Man hits the quality bar

**Exit criteria:**

- [ ] Repeatable benchmark run via `tools/benchmark/`.
- [ ] Numbers meet bar in `docs/TELEMETRY.md` on the demo Mac.
- [ ] Warm-cache launch: no hitch.
- [ ] Controller + KBM input checked.
- [ ] Side-by-side vs Windows at a comparable preset is a credible demo.

---

### M4 — Pipeline, not a one-off

- [ ] Second title, different engine, different API. Same Play button. Less hand-holding.

---

## What we do NOT build or buy

| Thing | Why not |
| --- | --- |
| CrossOver | Paid commercial software |
| Apple GPTK | Eval-only license, cannot redistribute |
| Windows license / VM | Not how this works — Wine is not a VM |
| A custom DirectX translator | That's a multi-year project; DXVK/vkd3d already exist |
| A store, cloud, or anti-cheat titles | Out of scope per `docs/MILESTONES.md` |

---

## Where each part of the build lives

| Work | Location |
| --- | --- |
| Mac app UI, Play/Stop | `apps/launcher/` |
| Wine prefix management, process spawn | `runtime/` |
| Per-game flags (env, args, upscaler) | `profiles/*.json` |
| Vendored Wine/DXVK/MoltenVK builds | `third_party/` (submodules or pre-built dylibs) |
| FPS / latency capture | `tools/benchmark/` |
| One-off setup scripts | `scripts/` |
| Strategy, ADRs, legal | `docs/` |

---

## Current state

See `docs/STATUS.md` for what is actually done. This file is the plan.

**Current build task:** `npm run bootstrap` (Wine on this Mac), then Play the smoke title.

Spawn is wired:

| File | Status |
| --- | --- |
| `runtime/Sources/MoggedRuntime/WineEnvironment.swift` | done |
| `runtime/Sources/MoggedRuntime/BackendLauncher.swift` | done |
| `runtime/Sources/MoggedRuntime/ProcessHandle.swift` | done |
| `runtime/Sources/MoggedRuntime/RuntimeSupervisor.swift` | launch + stop live |
| `~/Library/Application Support/Mogged/backend.json` | written on first launch |
