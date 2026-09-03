# Glossary

User-facing language is Play, Installing, Running. The table below is for engineers.

| Term | Meaning here |
| --- | --- |
| **Mogged / Mogged.app** | The product: native macOS desktop app. |
| **Launcher** | `apps/launcher` — Swift UI, the only user-facing process. |
| **Runtime** | Hidden `runtime/` process: env, spawn, caches, logs. |
| **Profile** | JSON in `profiles/`: how Mogged launches one title. |
| **Smoke title** | Free Steam Windows game used to prove Play. |
| **Primary demo** | Spider-Man Remastered — the quality proof. |
| **Backend** | Swappable execution engine the runtime calls. Not shown in the UI. |
| **D3DMetal** | DirectX (11/12) → Metal. Preferred graphics path. |
| **MetalFX / FSR** | Upscalers we can actually use on a Mac. DLSS is NVIDIA-only. |
| **Hitch** | A frame much longer than the median; usually shader/PSO compile. |
| **PSO cache** | Pipeline-state cache. Nixxes ships one for Spider-Man. |
| **EAC / BattlEye** | Kernel anti-cheat. Hard no for MVP titles. |
| **GPTK** | Apple Game Porting Toolkit. **Eval/dev only.** Not the product. |
| **Prefix / bottle** | Isolated Windows-like tree. Implementation detail. Never in the UI. |
