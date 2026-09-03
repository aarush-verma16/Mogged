# Scripts

Prefer npm from the repo root:

```bash
npm start      # launch Mogged.app
npm run dev    # same
npm test
npm run build
```

| Script | What |
| --- | --- |
| `scripts/run-mogged.sh` | Build, bundle, open Mogged.app |
| `scripts/test.sh` | Runtime tests + launcher compile |
| `scripts/bootstrap-runtime.sh` | Gcenx Wine + MoltenVK + DXVK-macOS (free). `npm run bootstrap` |

Keep scripts idempotent. Do not copy eval toolkits into git.
