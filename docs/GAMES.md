# Titles

Selection is a product decision, not a Steam sale decision. A title that needs kernel anti-cheat or a Mac native build does not prove Mogged.

## Criteria (every title)

Must satisfy all of:

1. **No kernel-level anti-cheat** (Easy Anti-Cheat, BattlEye, Vanguard, etc.). Steam VAC-only is still discouraged for the smoke title.
2. **No macOS native build** we could accidentally launch instead of the Windows build.
3. **Offline or single-player capable.**
4. **DirectX 11 or 12 preferred** for anything that is supposed to predict Spider-Man. Vulkan/Source 2 is acceptable only as *plumbing* smoke.
5. **Already known to run** in CrossOver and/or GPTK community reports — we optimize, we do not debug a broken title from zero.

## Ladder

First boot on this Mac is Aperture Desk Job (ADR-012). It passes the criteria. Apex and Rivals (ADR-010) **fail** criterion 1 (anti-cheat). We still keep them pinned to see boot behavior after the stack is proven.

| Stage | Title | Steam AppID | Why |
| --- | --- | --- | --- |
| First (safe) | **Aperture Desk Job** | `1902490` | Light smoke. Free, ~3 GB, no AC. ADR-012. |
| Next | **Apex Legends** | `1172470` | Founder target. DX11, EAC. Online likely blocked. |
| Then | **Marvel Rivals** | `2767030` | Founder target. UE5 / DX12, ACE. Online likely blocked. |
| Later | **Marvel's Spider-Man Remastered** | `1817070` | Quality demo. No AC. Not listed until M2 / Steam has it. |
| Explicitly not MVP | Elden Ring, Nightreign | — | Still not MVP. |

Profiles live in `/profiles`. Change first titles only with an ADR.

## Primary: Spider-Man Remastered

| Field | Value |
| --- | --- |
| Engine | Insomniac, PC port by Nixxes |
| API | Direct3D 12 (not 11) |
| Anti-cheat | None |
| Upscaling | DLSS (NVIDIA, ignore), FSR 2 (use), MetalFX (explore) |
| Ray tracing | Supported; **off** for MVP bar |
| Shaders | Nixxes ships a PSO cache beside the game — steal this idea, do not ignore it |
| Input | KBM + DualSense; verify latency, not just mapping |
| Known Mac-class issues | Cutscene / silent crashes in CrossOver reports; RT/VRAM false positives when `SteamDeck=1`; DLSS missing |

Success is not "it opened." Success is a repeatable benchmark vs a Windows PC at a comparable quality preset (FSR/MetalFX standing in for DLSS). Numbers: [TELEMETRY.md](TELEMETRY.md).

## Adding a title

1. Check criteria above.
2. Add `profiles/<id>.json` from `_schema.json`.
3. Note ProtonDB + CrossOver + GPTK links in the profile `research` block.
4. If it is not smoke/Spider-Man, write an ADR.

Do not keep a living 200-game spreadsheet. Two titles plus one smoke is the MVP.
