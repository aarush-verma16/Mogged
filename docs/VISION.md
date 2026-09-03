# Vision

## Sentence

Mogged makes Windows PC games feel native on a Mac — not "compatible," not "via Wine," not "in a VM." Open the app. Click Play. The game runs well.

## Why this is a product, not a frontend for Wine

Compatibility layers already exist (Wine, CrossOver, GPTK, Whisky, Proton). Players still have to know what a bottle is, pick a Windows version, install Steam-inside-Wine, and google launch flags. That is a hobbyist workflow.

Mogged's job is the last mile:

- Find the installed Windows game.
- Apply a known-good profile (translation flags, resolution/upscaler, shader cache, controller map).
- Launch it.
- Keep it smooth (shader precompile, frame-pacing, input path).
- When it breaks, capture a crash log a human can act on — without exposing the stack.

The translation layer is infrastructure. The product is "it just runs."

## Proof we are aiming at

A side-by-side of *Marvel's Spider-Man Remastered* on a Windows PC vs the same title through Mogged on Apple Silicon, where the gap is small enough to show someone who is not a Wine user.

That proof is gated:

1. A free Steam Windows game launches from our shell (plumbing works).
2. Spider-Man Remastered boots to gameplay with no manual config (it runs at all).
3. Spider-Man hits a defined FPS / hitch / latency bar (it runs well).
4. A second, different-engine title uses the same pipeline with less hand-holding (it is a platform, not a one-off).

## What "near-native" means here

Not "identical to a 4090." It means:

- Stable, watchable frame rate on the target Mac (see `TELEMETRY.md` for the numeric bar).
- Frame times that do not hitch every camera swing or shader compile.
- Input that feels like a local game, not a remote desktop.
- Image quality that uses Metal-side upscaling (MetalFX / FSR), not missing NVIDIA DLSS as a failure.

## What this company is not (yet)

Not a cloud game-streaming company. Not a store. Not a 10,000-title compatibility spreadsheet. Those might be later businesses. The MVP is a runtime plus a launcher that makes two titles look inevitable.
