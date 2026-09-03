# Benchmark

Repeatable FPS / frame-time / hitch / latency capture.

**Status:** not started. Skeleton the logger in Phase 1 even if the HUD is developer-only. Phase 2 is judged by this folder.

## Intended output

One JSON per run in `results/` (gitignored):

```json
{
  "titleId": "spider-man-remastered",
  "machine": "Mac16,x",
  "backend": "d3dmetal",
  "resolution": "1920x1080",
  "upscaler": "fsr-quality",
  "firstRun": false,
  "avgFps": 0,
  "p1Fps": 0,
  "hitchCount": 0,
  "gitSha": ""
}
```

Bars and rules: `docs/TELEMETRY.md`. Scene route lives on the title profile (`benchmark.route`).
