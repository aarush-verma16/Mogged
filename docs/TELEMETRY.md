# Telemetry and quality bar

If it is not in a log, it did not happen. Phase 1 records these. Phase 2 is judged by them.

## Always capture

| Signal | What good looks like | Notes |
| --- | --- | --- |
| Average FPS | See title bars below | Exclude menus / loading |
| 1% / 0.1% lows | Close to average (pacing) | Hitching is the usual Wine tell |
| Frame time stdev / hitch count | Hitch = frame ≥ 2× median | Shader compile spikes belong here |
| Input latency | Controller and KBM, ms click-to-photon if we can; else click-to-swap | "Mapped" ≠ "fast" |
| Load time to first gameplay | Trend down after cache warm | First-run vs second-run is the shader story |
| Crash / hang | Zero in a 30 min scripted path | Keep full Wine/GPTK log internally |
| GPU / CPU power (optional) | Not a ship gate | Useful vs thermal throttling on laptops |

Store raw runs under `tools/benchmark/results/` (gitignored except fixtures). One JSON per run: title id, git sha, Mac model, backend (`d3dmetal` / `dxvk-moltenvk`), preset, resolution, upscaler, first-run yes/no.

## Spider-Man Remastered (Phase 2 gate)

Target Mac: the Apple Silicon machine we actually demo on. Write the model into `STATUS.md` when we know it.

Working bar (revise with an ADR if the hardware is an Air vs a Max):

- **Playable:** ≥ 40 FPS average at 1080p-class internal res, FSR/MetalFX quality, RT off, during traversal + one combat encounter.
- **Demo-credible:** ≥ 55 FPS average, 1% low ≥ 30, hitch count near zero after warm cache, input that does not feel buffered.
- **First-run:** hitching allowed. **Second launch:** must match the demo-credible pacing bar.

Compare against a Windows PC at the same resolution and a similar preset (FSR vs DLSS Quality is the fair swap). The video is the artifact; the JSON is the argument.

## Smoke title (Phase 1 gate)

No FPS heroics. Gates:

- Cold launch → gameplay (or the Desk Job intro) without a terminal or config file.
- Second launch is unattended Play.
- A crash log exists if it dies.

## Harness rules

- Same scene, same camera path, same duration (record a 60s or 180s route per title in the profile).
- Disable the Steam overlay for measurement runs.
- Do not compare a first-run shader compile against a warmed Windows install.
- Never quote "feels like 60" in STATUS without a file path to the run.
