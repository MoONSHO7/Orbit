# GitHub Actions — Orbit

Four workflows, one release pipeline, one lint gate, one weekly data refresh.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| [`lint.yml`](lint.yml) | pull request, push to `main` | Runs `check-localization.sh` as a status check |
| [`auto-tag.yml`](auto-tag.yml) | push to `main` | Calculates next version and creates a tag |
| [`release.yml`](release.yml) | tag push matching `X.Y.Z` | Builds and packages the addon, publishes to CurseForge |
| [`weekly_meta_update.yml`](weekly_meta_update.yml) | cron (Wed 12:00 UTC) + manual | Refreshes WCL talent meta data, commits, triggers a release |

---

## Versioning scheme

```
MAJOR . MINOR . PATCH
  0   .  248  .   0
  │      │        │
  │      │        └─── bumped by `data:` commits (weekly meta refresh)
  │      └──────────── bumped by regular commits / PR merges to main
  └─────────────────── manual only (we are pre-1.0)
```

- **MAJOR** — manual only. `git tag -a 1.0.0 -m "First stable" && git push origin 1.0.0`.
- **MINOR** — auto-bumped on every non-`data:` commit to `main`.
- **PATCH** — auto-bumped on every commit whose message starts with `data:` (currently only the weekly WCL refresh).

After a manual major bump, auto-tag transparently continues from the new major — no workflow changes needed.

---

## Release chains

### A. Regular commit / PR merge

```
push to main (commit msg: "feat: ...")
   ↓
auto-tag.yml
   ↓ detects non-data commit, bumps MINOR, resets PATCH
   ↓ creates & pushes tag 0.249.0 (uses ORBIT_PAT so downstream workflows fire)
   ↓
release.yml (glob [0-9]*.[0-9]*.[0-9]* matches)
   ↓ runs update_changelog.py
   ↓ BigWigsMods/packager → CurseForge
```

### B. Weekly data refresh

```
Wednesday 12:00 UTC
   ↓
weekly_meta_update.yml
   ↓ runs .scripts/build_meta.py (fetches WCL rankings, writes OrbitData/TalentMeta.lua)
   ↓ commits "data: Auto-update Weekly Meta Talents" and pushes to main (ORBIT_PAT)
   ↓
auto-tag.yml
   ↓ detects `data:` prefix, bumps PATCH only
   ↓ creates & pushes tag 0.248.1
   ↓
release.yml
   ↓ same as above — CurseForge release
```

### C. Manual major bump

```
git tag -a 1.0.0 -m "First stable release"
git push origin 1.0.0
   ↓
release.yml (skips auto-tag entirely)
   ↓ CurseForge release 1.0.0
```

After `1.0.0` exists, the next regular commit produces `1.1.0`, next data commit produces `1.0.1`.

---

## Auto-tag bootstrap

On first run after adopting the `X.Y.Z` scheme, there are no existing `[0-9]*.[0-9]*.[0-9]*` tags. The script bootstraps from the highest legacy **integer** tag (the pre-semver auto-tags), treating it as the implied previous `0.N.0`:

| Before bootstrap | First commit type | Result |
|------------------|-------------------|--------|
| Latest legacy = `247` | regular | `0.248.0` (minor bumped) |
| Latest legacy = `247` | `data:` | `0.247.1` (patch bumped) |
| No legacy tags at all | regular | `0.1.0` |
| No legacy tags at all | `data:` | `0.0.1` |

This preserves history continuity — the new middle number picks up where the old single number left off.

---

## Lint status check

`lint.yml` runs `.scripts/check-localization.sh` on every pull request targeting `main`. It catches:

- **Orphan references** — `L.KEY` used in code but not defined in any domain file
- **Cross-domain collisions** — same key defined in two domain files
- **Prefix isolation breaks** — a domain prefix appearing in the wrong file

Non-fatal warnings:
- **Unused keys** — defined but not yet referenced (expected during migration phases)

### Making it a required check

GitHub Actions alone can't mark a check as *required*. One-time repo setup:

1. **Settings → Branches → Branch protection rules** → edit rule for `main`
2. Enable **Require status checks to pass before merging**
3. Search for `Lint / Localization` and add it
4. Save

---

## Secrets

All workflows rely on repository secrets. If any of these expire/rotate, the chain breaks silently at the step that uses them — check workflow logs.

| Secret | Used by | Purpose | Notes |
|--------|---------|---------|-------|
| `ORBIT_PAT` | `auto-tag.yml`, `weekly_meta_update.yml` | Checkout + push with elevated permissions so downstream workflows fire | **Critical** — if this expires, tags pushed by GH Actions will not trigger release.yml (the default `GITHUB_TOKEN` suppresses downstream workflow runs). Set a renewal reminder. |
| `CURSE_API_KEY` / `CF_API_KEY` | `release.yml` | Upload package to CurseForge via BigWigsMods/packager | |
| `WCL_CLIENT_ID` | `weekly_meta_update.yml` | Authenticate with Warcraft Logs OAuth | |
| `WCL_CLIENT_SECRET` | `weekly_meta_update.yml` | Authenticate with Warcraft Logs OAuth | |

---

## Operational notes

### Why tag pushes need a PAT

GitHub Actions deliberately prevents infinite loops by suppressing downstream workflow runs when a workflow pushes using the default `GITHUB_TOKEN`. To make `auto-tag.yml`'s tag push trigger `release.yml`, the push must use a Personal Access Token (here: `ORBIT_PAT`). Both `actions/checkout@v4` and subsequent `git push` commands in the auto-tag job use this token.

### Race-condition guard

If two commits hit `main` in rapid succession, two auto-tag jobs may try to create the same tag. The script checks `git rev-parse "$VERSION"` first and exits cleanly if the tag already exists. The second run effectively no-ops.

### Branch protection compatibility

The `weekly_meta_update.yml` job commits directly to `main`. If you later enable *strict* branch protection requiring PRs for every change, the weekly workflow will start failing. Workarounds:

- Allow the PAT owner (or the GitHub App) to bypass branch protection, or
- Change `weekly_meta_update.yml` to open a PR and auto-merge it (more setup, more resilient)

Current setup assumes direct push is allowed.

### What **won't** trigger a release

- Legacy integer tags (`247`, `266-alpha`) — filter excludes them
- Historical `v1.3.5` / `v1.3.5-data.1` semver-with-prefix tags
- Anything that's not exactly three dot-separated digit-led segments

If you need to re-release any of those, manually create a new `X.Y.Z` tag.

---

## Rollout verification checklist

To confirm the chain works end-to-end after any workflow change:

1. Merge a small no-op PR (docs edit, comment) to `main`.
2. Watch the Actions tab: `Auto Tag` should run, create a new `X.Y.Z` tag.
3. `Release AddOn` should then fire on the new tag.
4. Check CurseForge for the new release within a few minutes.
5. `/dump Orbit.version` in-game after updating should show the new version string.

If any step fails, the job logs identify the exact break point. The most common failure is `ORBIT_PAT` expiry (auto-tag push succeeds but release.yml never fires — symptom: new tag appears but no release workflow run).
