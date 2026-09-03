# Runtime

Hidden process behind Mogged.app. Not user-facing.

**Status:** not started. **M1.** Decision 1 (which backend we spawn) is still open.

## Intended shape

- Apply profile env/args and spawn the Windows exe.
- Persist shader/PSO caches.
- Stream logs for `tools/benchmark`.
- Backend names: `d3dmetal` | `dxvk-moltenvk` | `moltenvk` | `vkd3d-moltenvk`.

Point at a local eval install via config. Do not put GPTK or CrossOver.app in this tree.

See `.cursor/rules/runtime.mdc`, `docs/ARCHITECTURE.md`, `docs/LEGAL.md`.
