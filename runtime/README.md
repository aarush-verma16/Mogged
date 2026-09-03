# Runtime

Hidden supervisor around a Wine-class translation stack.

**Status:** not started. Phase 1. Decision 1 (which binary we spawn) is still open.

## Intended shape

- Create/update a prefix per title (or a shared Steam prefix).
- Apply profile env/args.
- Spawn the Windows exe without a TTY workflow.
- Stream logs + crash wrappers for `tools/benchmark`.
- Backend names: `d3dmetal` | `dxvk-moltenvk` | `moltenvk` | `vkd3d-moltenvk`.

Config should point at a Wine/CrossOver/GPTK *eval* install on disk. This tree must not contain GPTK or CrossOver.app.

See `.cursor/rules/runtime.mdc`, `docs/ARCHITECTURE.md`, `docs/LEGAL.md`.
