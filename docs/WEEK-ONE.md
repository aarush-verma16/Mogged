# This week (Phase 0, hands-on)

Goal: a Windows program launches on this Mac through GPTK **and** through CrossOver, then the same free Steam game in both. Write the comparison in `STATUS.md`. That is Decision 1's evidence.

Do this on the machine, not in this git repo. Do not commit installers, prefixes, or games.

## 0. Record the Mac

```bash
sysctl -n machdep.cpu.brand_string
sw_vers
uname -m   # must be arm64
```

Paste the three lines into `docs/STATUS.md`. If you are not on Apple Silicon, stop.

## 1. Game Porting Toolkit (eval)

1. On [Apple Developer – Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/), download the newest toolkit **that lists your macOS version**.
2. Read the **license text in that download**. Three sentences into `docs/DECISIONS.md` ADR-002: can we redistribute, to whom, commercial or not.
3. Install per Apple's current README (this changes every GPTK major). Older flow was a brew bottle + `gameportingtoolkit` prefix; newer CrossOver builds expose D3DMetal as a bottle setting. Follow the file you just downloaded, not a 2023 blog.
4. Success: any Windows exe starts (Steam setup, notepad from the Wine prefix, DirectX sample). Screenshot internally if you want; no UI copy that says GPTK.

## 2. CrossOver (eval)

1. Install current CrossOver for Mac from CodeWeavers.
2. Create a bottle, install Steam (Windows) or the smoke title, enable the D3DMetal / GPTK-related option if the UI offers one.
3. Success: same Windows exe or same game as step 1.

## 3. Same smoke title, both stacks

Default: **Aperture Desk Job** (Steam app `1902490`), free. Needs a controller.

If Steam-in-prefix is too much friction for day one, any tiny Windows exe is enough for *stack* bring-up — but the week is not done until a **real Steam game** has been launched in both.

Capture for each stack:

- Did it boot?
- Minutes to first pixel.
- Any manual winetricks / DLL overrides (this is what our runtime must hide later).
- Rough FPS or "unplayable / playable / fine."
- Crash notes.

Put that table in `STATUS.md`. Then recommend a backend leaning in ADR-002 / Decision 1 (even if shipping still waits on legal).

## 4. Confirm the smoke title

If Aperture Desk Job is a dead end (Deck controls, Vulkan-only, won't start), pick the next free game from the shortlist in `GAMES.md` and update `profiles/` + ADR-003.

Do **not** start Spider-Man install until the smoke title has booted once in *some* stack. Spider-Man is the quality target, not the hello-world.

## 5. What not to do this week

- No Swift UI polish.
- No Steam store features.
- No Elden Ring.
- No committing CrossOver.app, GPTK, or `drive_c`.
- No "we will ship GPTK" in README.
