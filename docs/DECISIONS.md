# Decisions (ADR log)

Append-only. Newest first. Status is `proposed` | `accepted` | `superseded`.

When you lock something, update [STATUS.md](STATUS.md) and [MILESTONES.md](MILESTONES.md).

---

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
- **Open:** Confirm Aperture Desk Job after first GPTK/CrossOver boot; swap using `GAMES.md` shortlist if it teaches nothing about our stack.

## ADR-002 — Shipping runtime license

- **Status:** proposed
- **Leaning:** Use GPTK and CrossOver as **local test harnesses** in M0. Never redistribute Apple's toolkit. A shipping Mogged.app may only embed a backend we have license to distribute (OEM deal, or an OSS engine with compliance). That backend is not the product name.
- **Why:** GPTK is evaluation/development (non-commercial distribution of the Apple Software). CrossOver is commercial. OSS Windows-API stacks (e.g. LGPL) are a possible embed path, not a brand.
- **Block:** Counsel must read the current GPTK license and any embed obligations before any build leaves this machine. Local Play on our Macs is not blocked.

## ADR-001 — Monorepo

- **Status:** accepted
- **Decision:** One git repo (`Mogged`). Packages: `apps/launcher`, `runtime`, `profiles`, `tools/benchmark`. Split only if a real team boundary appears.
- **Why:** MVP speed. The launcher and runtime will churn together for months.

## ADR-000 — Do not write a Windows/DirectX translator

- **Status:** accepted
- **Decision:** We write the desktop app, profiles, caches, input, telemetry, and a hidden runtime. We do **not** implement ntdll, D3D, or a new translation layer. We call a swappable execution backend (D3DMetal-class). We are not "a Wine project."
- **Why:** The product is Mogged.app. Rebuilding a decade of syscall/graphics translation is not the MVP.
