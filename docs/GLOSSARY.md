# Glossary

Internal language. None of this belongs in the UI.

| Term | Meaning here |
| --- | --- |
| **Mogged** | The product: Mac launcher + hidden runtime. |
| **Prefix / bottle** | A fake Windows tree (drive_c, registry). User never names this. |
| **Wine** | LGPL Windows-API translation. Core of any stack we can ship ourselves. |
| **CrossOver** | CodeWeavers' commercial Wine, often with D3DMetal. Eval tool; ship only licensed. |
| **GPTK** | Apple Game Porting Toolkit. Eval/dev environment with D3DMetal. Do not redistribute. |
| **D3DMetal** | Apple's DirectX (11/12) → Metal translation. Preferred graphics path. |
| **DXVK** | D3D9/10/11 → Vulkan. Does not do D3D12. |
| **vkd3d-proton** | D3D12 → Vulkan. Combined with MoltenVK this is the slow extra-hop D3D12 path. |
| **MoltenVK** | Vulkan → Metal. |
| **Proton** | Valve's Wine+DXVK+vkd3d stack for Linux. Cousin, not our Mac runtime. |
| **Profile** | JSON in `profiles/`: how Mogged launches one title. |
| **Smoke title** | Free Steam Windows game used to prove Play plumbing. |
| **Primary demo** | Spider-Man Remastered — the quality proof. |
| **Hitch** | A frame much longer than the median; usually shader/PSO compile or a stall. |
| **PSO cache** | Pipeline-state cache. Nixxes ships one for Spider-Man; we should persist ours. |
| **MetalFX** | Apple spatial/temporal upscaler. Our DLSS stand-in when we can hook present. |
| **FSR** | AMD upscaler inside the game. Use when we cannot inject MetalFX. |
| **EAC / BattlEye** | Kernel anti-cheat. Hard no for MVP titles. |
