# Third party

Vendored Wine / DXVK / vkd3d-proton / MoltenVK builds go here when we ship them inside Mogged.app.

Do not commit the binaries. Paths:

```
third_party/wine/bin/wine64
third_party/dxvk/x64/*.dll
third_party/vkd3d-proton/x64/*.dll
third_party/moltenvk/libMoltenVK.dylib
```

Until those exist, the runtime uses Homebrew Wine and MoltenVK on this Mac. See `scripts/bootstrap-runtime.sh`.
