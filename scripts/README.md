# Scripts

Prefer npm from the repo root:

```bash
npm start      # launch Mogged.app
npm run dev    # same
npm test       # runtime tests + launcher build
npm run test:i # interactive terminal menu
npm run test:watch
npm run build
```

| Script | What |
| --- | --- |
| `scripts/run-mogged.sh` | Build, bundle, open Mogged.app |
| `scripts/test.sh` | Runtime tests + launcher compile. New `*Tests.swift` files are picked up automatically. `-i` menu, `--watch`, `--filter Steam` |
| `scripts/bootstrap-runtime.sh` | Gcenx Wine + MoltenVK + DXVK-macOS (free). `npm run bootstrap` |
| `scripts/fetch-windows-title.sh` | SteamCMD pulls the **Windows** depot. Default: Aperture Desk Job. `STEAM_USER=you npm run fetch` |

Keep scripts idempotent. Do not copy eval toolkits into git.
