# Runtime

Hidden library + CLI behind Mogged.app. Not user-facing.

```
swift test --package-path runtime
swift run --package-path runtime mogged-runtime list
swift run --package-path runtime mogged-runtime detect
```

`detect` may print toolkit names. That command is for us, not for the app UI.

## Layout

| Piece | Role |
| --- | --- |
| `MoggedRuntime` | Profiles, install detection, library overrides, telemetry, launch supervisor |
| `mogged-runtime` | CLI over the same library |

Launch will refuse until an execution backend is installed on this Mac **and** spawn is wired. The app shows a generic "can't start this game" message — never a toolkit name.

Config and logs: `~/Library/Application Support/Mogged/` and `~/Library/Logs/Mogged/`.
