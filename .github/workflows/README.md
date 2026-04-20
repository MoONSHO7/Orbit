# GitHub Actions — Orbit

Three workflows: one lint gate, one auto-tagger, one release pipeline.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| [`lint.yml`](lint.yml) | pull request, push to `main` | Runs `check-localization.py` as a status check |
| [`auto-tag.yml`](auto-tag.yml) | push to `main` | Calculates next version and creates a tag |
| [`release.yml`](release.yml) | tag push matching `X.Y.Z` | Builds and packages the addon, publishes to CurseForge |

---

## Versioning scheme

```
MAJOR . MINOR . PATCH
  0   .  249  .   0
  │      │        │
  │      │        └─── manual hotfixes only
  │      └──────────── bumped on every commit to main
  └─────────────────── manual only (we are pre-1.0)
```

- **MAJOR** — manual only. `git tag -a 1.0.0 -m "First stable" && git push origin 1.0.0`.
- **MINOR** — auto-bumped on every commit to `main`.
- **PATCH** — reserved for manual hotfix tags.

After a manual major bump, auto-tag transparently continues from the new major.

---

## Release chain

```
push to main
   ↓
auto-tag.yml
   ↓ bumps MINOR
   ↓ creates & pushes tag X.Y.0 (uses ORBIT_PAT so release.yml fires)
   ↓
release.yml (glob [0-9]*.[0-9]*.[0-9]* matches)
   ↓ runs update_changelog.py
   ↓ BigWigsMods/packager → CurseForge
```

Manual major bump:

```
git tag -a 1.0.0 -m "First stable release"
git push origin 1.0.0
   ↓
release.yml (skips auto-tag entirely)
```

---

## Auto-tag bootstrap

On first run after adopting the `X.Y.Z` scheme, there are no existing `[0-9]*.[0-9]*.[0-9]*` tags. The script bootstraps from the highest legacy integer tag, treating it as the implied previous `0.N.0`:

| Before bootstrap | Result |
|------------------|--------|
| Latest legacy = `247` | `0.248.0` |
| No legacy tags at all | `0.1.0` |

---

## Lint status check

`lint.yml` runs `.scripts/check-localization.py` on every pull request targeting `main`. It catches:

- **Orphan references** — `L.KEY` used in code but not defined in any domain file
- **Cross-domain collisions** — same key defined in two domain files
- **Prefix isolation breaks** — a domain prefix appearing in the wrong file

Non-fatal warnings:
- **Unused keys** — defined but not yet referenced

### Making it a required check

1. **Settings → Branches → Branch protection rules** → edit rule for `main`
2. Enable **Require status checks to pass before merging**
3. Search for `Lint / Localization` and add it
4. Save

---

## Secrets

| Secret | Used by | Purpose | Notes |
|--------|---------|---------|-------|
| `ORBIT_PAT` | `auto-tag.yml` | Checkout + push with elevated permissions so release.yml fires on the new tag | **Critical** — if this expires, tags pushed by GH Actions will not trigger release.yml (the default `GITHUB_TOKEN` suppresses downstream workflow runs). |
| `CURSE_API_KEY` / `CF_API_KEY` | `release.yml` | Upload package to CurseForge via BigWigsMods/packager | |

---

## Operational notes

### Why tag pushes need a PAT

GitHub Actions deliberately prevents infinite loops by suppressing downstream workflow runs when a workflow pushes using the default `GITHUB_TOKEN`. To make `auto-tag.yml`'s tag push trigger `release.yml`, the push must use a Personal Access Token (here: `ORBIT_PAT`).

### Race-condition guard

If two commits hit `main` in rapid succession, two auto-tag jobs may try to create the same tag. The script checks `git rev-parse "$VERSION"` first and exits cleanly if the tag already exists.

### What **won't** trigger a release

- Legacy integer tags (`247`, `266-alpha`) — filter excludes them
- Historical `v1.3.5` / `v1.3.5-data.1` semver-with-prefix tags
- Anything that's not exactly three dot-separated digit-led segments

If you need to re-release any of those, manually create a new `X.Y.Z` tag.

---

## Rollout verification checklist

1. Merge a small no-op PR (docs edit, comment) to `main`.
2. Watch the Actions tab: `Auto Tag` should run, create a new `X.Y.Z` tag.
3. `Release AddOn` should then fire on the new tag.
4. Check CurseForge for the new release within a few minutes.

If any step fails, the job logs identify the exact break point. The most common failure is `ORBIT_PAT` expiry (auto-tag push succeeds but release.yml never fires — symptom: new tag appears but no release workflow run).
