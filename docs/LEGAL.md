# Legal and license posture

This is Decision 2. **Local evaluation can start now. Redistributing a translation stack cannot.** Treat this file as blocking for any binary we would give another person.

This is not legal advice. Get a lawyer before the first external build. Record the outcome in [DECISIONS.md](DECISIONS.md).

## Components

### Our code (launcher, runtime supervisor, profiles, benchmark)

Proprietary. Do not copy code from CrossOver, Whisky, or GPTK samples into this repo without a license note.

### Wine

LGPL. We may wrap Wine in a shipping product if we comply: typically dynamic linking, providing object files / source for our Wine modifications, and preserving notices. If we patch Wine, those patches are LGPL. Budget time for compliance, not for rewriting Wine.

### DXVK, vkd3d-proton, MoltenVK

Each has its own OSS license (generally zlib / LGPL / Apache 2 compatible mix). Track exact versions in `third_party/` when we vendor or submodule them. Do not vendor until Decision 1 is closed.

### Apple Game Porting Toolkit (GPTK)

Apple's evaluation environment (D3DMetal, `gameportingtoolkit` / current CLI, Metal Shader Converter) is licensed for **developing, testing, or evaluating games on Apple hardware**. Distribution of the Apple Software is restricted (historically **non-commercial**, no rental/sale/hosting of the toolkit as a service, Apple-branded hardware only).

Implications:

- Installing GPTK on our Macs to run Spider-Man and smoke titles: **intended use.**
- Shipping Mogged with GPTK inside, or requiring users to install GPTK as the runtime: **assume forbidden** until counsel says otherwise.
- Open-source fragments Apple publishes (e.g. Apache-2 repos) are not the same as the toolkit DMG. Do not conflate them.

Whisky, Kegworks, and similar GPTK frontends are prior art for UX. They are not a license strategy.

### CrossOver / CodeWeavers

Commercial Wine with D3DMetal integration and per-title work. Using CrossOver locally for benchmarks is fine. Shipping CrossOver as our engine requires a **business license / OEM** conversation with CodeWeavers. Do not reverse engineer CrossOver or copy their bottle recipes into git as if they were ours.

### Steam, games, and DRM

We launch games the user already owns. We do not redistribute Spider-Man, Steam, or any game depot. Respect Steam's terms: no cracked exes, no bypassing Steam DRM, no sharing accounts in docs or scripts.

## Working policy (until counsel closes Decision 2)

| Action | Allowed now? |
| --- | --- |
| Install GPTK + CrossOver on a company/personal M-series Mac | Yes |
| Benchmark titles, write profiles, build the launcher against a swap-able runtime interface | Yes |
| Commit game files, Steam tokens, GPTK DMGs, CrossOver.app, Wine prefixes | No |
| Ship an alpha to friends that bundles GPTK | No |
| Ship an alpha that launches a user-installed CrossOver/GPTK | Ask counsel first |
| Ship an alpha that bundles LGPL Wine with a proper notice | Ask counsel; technically the usual OSS path |

## Founder task (not skippable)

Before Phase 1 code is treated as "the product":

1. Read the current GPTK license text in the Apple Developer download, not a blog summary.
2. Read Wine LGPL obligations for a macOS app bundle.
3. Decide: **Wine wrap**, **CrossOver OEM**, or **kill the distribution model**.
4. Write the answer into `docs/DECISIONS.md` as ADR-002.

Phase 0 engineering (getting a game to boot locally) does not wait on (3). Any **shared** build does.
