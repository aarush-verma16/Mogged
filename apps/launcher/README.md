# Launcher

macOS app. The only thing a player is supposed to look at.

**Status:** not started. Phase 1.

## Intended shape

- Swift + SwiftUI, Apple Silicon only.
- Loads `profiles/*.json` from the app bundle (or repo during dev).
- Detects Steam-for-Windows installs inside the runtime prefix and/or a user-picked folder.
- Play / Stop. Progress text that does not mention Wine.
- Talks to `runtime/` as a local helper.

See `.cursor/rules/launcher.mdc` and `docs/ARCHITECTURE.md`.

Do not add account, store, or bottle-manager UI.
