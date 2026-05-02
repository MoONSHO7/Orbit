# GitHub Actions — Orbit

| File | Trigger | Purpose |
|------|---------|---------|
| [`lint.yml`](lint.yml) | PR / push to `main` | `check-localization.py` status check |
| [`auto-tag.yml`](auto-tag.yml) | push to `main` (paths: `Orbit/**`, `.scripts/**`, `.pkgmeta`, `CHANGELOG.md`) | Bumps MINOR, pushes `X.Y` tag |
| [`release.yml`](release.yml) | tag push `X.Y` / `X.Y.Z` / `X.Y-alpha.*` | BigWigs packager → CurseForge (alpha or release channel by tag suffix) |
| [`alpha-release.yml`](alpha-release.yml) | manual (`workflow_dispatch`) | Tags `ai-develop` HEAD as `X.Y-alpha.<timestamp>` |
| [`claude-issues.yml`](claude-issues.yml) | issue labeled `claude-approved` (owner only) | Claude fixes the issue on `ai-develop`, maintains a rolling PR to `main` |

## Versioning

`MAJOR.MINOR` — MAJOR is manual (`git tag -a 1.0 -m "..." && git push origin 1.0`), MINOR auto-bumps on every qualifying push to `main`. Alpha tags are filtered out when computing the next stable version.

## Secrets

| Secret | Used by | Notes |
|--------|---------|-------|
| `ORBIT_PAT` | `auto-tag.yml`, `alpha-release.yml` | Personal access token. **Required** — default `GITHUB_TOKEN` won't trigger downstream `release.yml` on tag push. |
| `CURSE_API_KEY` / `CF_API_KEY` | `release.yml` | CurseForge upload auth |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude-issues.yml` | Generate via `claude setup-token`. Consumes Pro/Max 5-hour quota — swap for `ANTHROPIC_API_KEY` if it bottlenecks. |
| `CLAUDE_RULES` | `claude-issues.yml` | Trimmed copy of project rules (the local CLAUDE.md without sub-addon refs / slash commands). Up to 48 KB. |

## Claude issue resolver

**Setup** (one-time):

1. Create labels `claude-approved` and `claude-failed`.
2. Create `ai-develop` branch: `git checkout -b ai-develop main && git push -u origin ai-develop`.
3. Add secrets `CLAUDE_CODE_OAUTH_TOKEN` and `CLAUDE_RULES` (see above).
4. Install [github.com/apps/claude](https://github.com/apps/claude) on the repo.
5. Settings → Actions → General → check "Allow GitHub Actions to create and approve pull requests".

**Flow**: label issue `claude-approved` → workflow gate (label + owner) → sync `ai-develop` ← `main` → Claude commits `fix(#N): ...` → posts detail comment → upserts rolling PR `ai-develop → main` → removes label.

**Failure path**: any step failure posts a comment with run URL + likely causes and applies `claude-failed`. Re-add `claude-approved` to retry.

**Concurrency**: `claude-bot` group serializes runs.

**Reverting**: `git revert <sha>` on `ai-develop` (fixes are direct commits, not per-issue branches).

## Alpha publishing

Manual trigger: **Actions → Alpha Release → Run workflow** (or `gh workflow run alpha-release.yml`). Always tags `ai-develop` HEAD regardless of trigger context. `release.yml` then publishes to the CurseForge alpha channel (skips `update_changelog.py` — changelog tracks stable only).

## Common breakages

- **Tag created but no release run** → `ORBIT_PAT` expired.
- **CurseForge upload fails** → `CURSE_API_KEY` rotated.
- **Claude run silently fails to start** → label gate not satisfied (must be repo owner adding `claude-approved`) or `CLAUDE_CODE_OAUTH_TOKEN` expired.
