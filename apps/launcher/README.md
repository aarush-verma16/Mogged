# Launcher

Native macOS desktop app. This is the product.

```bash
./scripts/run-mogged.sh
```

Or open `apps/launcher/Package.swift` in Xcode and run the `Mogged` target.

## Now

- Loads `profiles/*.json` (no hardcoded titles).
- Sidebar library. Play / Locate / Stop.
- Locate remembers a folder in `~/Library/Application Support/Mogged/library.json`.
- Play talks to `MoggedRuntime`. Games will not actually start until M0 eval backends exist on this Mac and spawn is wired.

## Not this app

Store, accounts, toolkit settings, Windows-version pickers.
