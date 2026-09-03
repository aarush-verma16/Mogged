# Third party

Vendored Wine / DXVK / vkd3d-proton / MoltenVK builds go here when we ship them inside Mogged.app.

Do not commit the binaries. Paths:

```
third_party/wine/bin/wine64
third_party/dxvk/x64/*.dll
third_party/vkd3d-proton/x64/*.dll
third_party/moltenvk/libMoltenVK.dylib
```

Until those exist, `npm run bootstrap` installs Gcenx Wine under `~/Library/Application Support/Mogged/engine/`, Homebrew MoltenVK, and DXVK-macOS DLLs here (gitignored).
