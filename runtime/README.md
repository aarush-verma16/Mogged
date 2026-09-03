# Runtime

Hidden library + CLI behind Mogged.app. Not user-facing.

```
swift test --package-path runtime
swift run --package-path runtime mogged-runtime list
swift run --package-path runtime mogged-runtime detect
```

`detect` may print engine names. That command is for us, not for the app UI.

## Layout

| Piece | Role |
| --- | --- |
| `MoggedRuntime` | Profiles, install detection, Wine environment, spawn, telemetry |
| `mogged-runtime` | CLI over the same library |

Play creates `~/Library/Application Support/Mogged/environments/<title-id>/`, writes `backend.json` if needed, and execs Wine. If Wine is missing the app shows a generic "can't start this game" message — never a toolkit name.

Install Wine locally with `npm run bootstrap`. Do not commit it.

Config and logs: `~/Library/Application Support/Mogged/` and `~/Library/Logs/Mogged/`.
