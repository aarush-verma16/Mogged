# Decisions (ADR log)

Append-only. Newest first. Status is `proposed` | `accepted` | `superseded`.

When you lock something, update [STATUS.md](STATUS.md) and [MILESTONES.md](MILESTONES.md).

---

## ADR-010 — First titles: Apex Legends and Marvel Rivals

- **Status:** accepted
- **Decision:** The first Play targets are **Apex Legends** (`1172470`) then **Marvel Rivals** (`2767030`). Aperture Desk Job is no longer the smoke title. Both are always listed (`pinned`). Spider-Man Remastered stays later.
- **Why:** Founder wants these running on this Mac first. Both have kernel/online anti-cheat (EAC / ACE). They may not reach a match. Boot + stack traces are still the experiment. Recorded so we do not pretend GAMES.md anti-cheat rule was followed.

## ADR-009 — Operator UI shows the stack

- **Status:** accepted
- **Decision:** This Mac's Mogged window is an **operator console**: Wine path, prefix, PID, env, DXVK/vkd3d, Steam disk state, `runtime.jsonl`, per-title logs. Not a consumer launcher. ADR-004 (no toolkit names in UI) does not apply to this surface until we ship to someone else.
- **Why:** One user, need to see what the runtime is doing.

## ADR-008 — Library is local Steam, Mogged UI

- **Status:** accepted
- **Decision:** The in-app library is games read from the Steam client on this Mac (library folders, manifests, login). Mogged draws its own UI. We do not embed or clone Steam's UI. First Play targets are Apex Legends and Marvel Rivals (ADR-010). Spider-Man Remastered stays a later milestone and is not listed unless it is actually in that local Steam library.
- **Why:** The product is a Mac game app that uses the games you already own. Hardcoding two JSON titles is not a library.

## ADR-007 — `dev` vs `main`

- **Status:** accepted
- **Decision:** Daily work and PRs land on `dev`. `main` is a freeze of `dev` when we explicitly snapshot a milestone. See [BRANCHING.md](BRANCHING.md).
- **Why:** Two long-lived branches; keep `main` boring.

## ADR-006 — Native desktop app, not a compatibility product

- **Status:** accepted
- **Decision:** Mogged is a native macOS desktop application. That is the product. We do not build a Wine/GPTK/CrossOver frontend, bottle manager, or toolkit GUI. Hidden execution backends are infrastructure and must stay replaceable and invisible.
- **Why:** The company is a gaming app, not a compatibility hobby. User-facing work lives in `apps/launcher`.

## ADR-005 — Elden Ring is not the MVP demo

- **Status:** accepted
- **Decision:** Primary quality demo is Marvel's Spider-Man Remastered. Elden Ring is a later gated benchmark only.
- **Why:** Spider-Man is DX12, no anti-cheat, Proton/CrossOver-proven, and heavy enough to be honest. Elden Ring adds FromSoftware/EAC uncertainty the MVP does not need.

## ADR-004 — User-facing language

- **Status:** accepted
- **Decision:** The app, marketing, and demo scripts never mention Wine, bottles, prefixes, GPTK, Proton, CrossOver, or virtualization. Architecture/legal docs and debug logs may, because engineers still have to name backends.
- **Why:** Mogged is a desktop game app. Toolkit names in the UI would make it a frontend.

## ADR-003 — Title ladder

- **Status:** accepted (smoke title still confirmable)
- **Decision:** Smoke = free Windows Steam game (default Aperture Desk Job). Primary = Spider-Man Remastered. Second title TBD in **M4**. No third title in MVP.
- **Why:** Need a zero-cost plumbing test before buying/installing a 80GB+ DX12 game, then one demanding single-player proof.
- **Open:** Apex + Rivals are the operator first titles (ADR-010). Confirm after first boot.

## ADR-002 — Shipping runtime license

- **Status:** accepted (local product path). Counsel still required before any binary leaves this Mac.
- **Decision:** The execution stack is **Wine (LGPL) + DXVK + vkd3d-proton + MoltenVK**. Zero paid software. We do not buy CrossOver. We do not install or redistribute Apple GPTK.
- **Why:** We need a Windows-game runtime we can actually ship inside Mogged.app. GPTK is eval-only. CrossOver is paid. The OSS stack is the only path that matches [BUILD.md](BUILD.md).
- **Block:** LGPL notices + dynamic linking before a shared `.app`. Local Play on this Mac is not blocked.

## Decision 1 — Execution backend

- **Status:** accepted
- **Decision:** Hidden runtime calls Wine. Graphics: `moltenvk` (Vulkan), `dxvk-moltenvk` (D3D9/11), `vkd3d-moltenvk` (D3D12). Path is in `~/Library/Application Support/Mogged/backend.json`, auto-written on first run.

## ADR-001 — Monorepo

- **Status:** accepted
- **Decision:** One git repo (`Mogged`). Packages: `apps/launcher`, `runtime`, `profiles`, `tools/benchmark`. Split only if a real team boundary appears.
- **Why:** MVP speed. The launcher and runtime will churn together for months.

## ADR-000 — Do not write a Windows/DirectX translator

- **Status:** accepted
- **Decision:** We write the desktop app, profiles, caches, input, telemetry, and a hidden runtime. We do **not** implement ntdll, D3D, or a new translation layer. We call a swappable execution backend (D3DMetal-class). We are not "a Wine project."
- **Why:** The product is Mogged.app. Rebuilding a decade of syscall/graphics translation is not the MVP.
