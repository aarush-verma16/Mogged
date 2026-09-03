# Launcher

Native macOS desktop app. This is the product.

```bash
npm start
```

UI follows Vercel/Geist tokens in `Theme.swift` (Geist, `#000` canvas, 6px controls). Do not restyle ad hoc.

## Now

- Loads `profiles/*.json` (no hardcoded titles).
- Sidebar library. Play / Locate / Stop.
- Locate remembers a folder in `~/Library/Application Support/Mogged/library.json`.
- Play talks to `MoggedRuntime`. Games will not actually start until M0 eval backends exist on this Mac and spawn is wired.

## Not this app

Store, accounts, toolkit settings, Windows-version pickers.
