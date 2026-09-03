# Branches

Two long-lived branches. Work happens on **`dev`**. **`main`** is the last snapshot we would hand someone.

```
feature/*  →  dev  →  main
                 daily     freeze
```

## Rules

| Branch | Purpose | Who commits |
| --- | --- | --- |
| `dev` | Integration. App, runtime, profiles, docs. | Everyday work |
| `main` | Frozen milestone. Should stay runnable. | Merge from `dev` only when asked to freeze |

- Do not commit directly to `main`.
- Do not open feature PRs against `main` (use `dev`).
- `main` → `dev` only to catch a hotfix that landed on `main` (rare).
- Never force-push `main`. Do not force-push `dev` unless the user explicitly asks.

## Daily

```bash
git checkout dev
git pull
# ... work ...
git push -u origin dev
```

## Freeze (only when asked)

```bash
git checkout main
git pull
git merge --no-ff dev
git push origin main
```

Prefer a GitHub PR `dev` → `main` over a local merge so the freeze is reviewable.

## GitHub

- Default branch on GitHub can stay `main` (clone/release).
- Set PR base to `dev` for ongoing work.
- CI runs on both branches (`.github/workflows/ci.yml`).
