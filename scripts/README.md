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

Keep scripts idempotent. Do not copy eval toolkits into git.
