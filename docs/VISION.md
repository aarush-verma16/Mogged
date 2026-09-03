# Vision

## Sentence

Mogged is a **native Mac desktop app** that plays Windows PC games on Apple Silicon. Open the app. Click Play. The game runs well.

It is a gaming product, not a compatibility layer with a GUI.

## What we are building

A Swift desktop application people install and use like any other Mac game launcher — except the library can include Windows titles.

The app:

- Finds the installed game.
- Applies a known-good profile (settings, upscaler, shader cache, controller map).
- Launches it.
- Keeps it smooth (precompile, frame-pacing, input).
- Captures a useful crash report if it dies — without exposing internals.

Anything that translates Windows/DirectX underneath is **infrastructure**. It must stay invisible. We are not shipping a hobbyist frontend for someone else's toolkit.

## Proof we are aiming at

A side-by-side of *Marvel's Spider-Man Remastered* on a Windows PC vs the same title in Mogged on Apple Silicon, where the gap is small enough to show a normal gamer.

Order of proofs is [MILESTONES.md](MILESTONES.md). No dates.

## What "near-native" means

Not "identical to a 4090." It means:

- Stable, watchable frame rate on the target Mac ([TELEMETRY.md](TELEMETRY.md)).
- Frame times that do not hitch every camera swing or shader compile.
- Input that feels local, not remote.
- Image quality via MetalFX / FSR — missing NVIDIA DLSS is expected, not a failure.

## What this is not (yet)

Not cloud streaming. Not a store. Not a 10,000-title spreadsheet. Not a virtualization product. The MVP is a desktop app that makes two titles look inevitable.
