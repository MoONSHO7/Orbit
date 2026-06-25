# github actions — orbit

| file | trigger | purpose |
|---|---|---|
| [`lint.yml`](lint.yml) | pr / push to `main` | four status checks: `check-localization.py`, `check-readmes.py`, `check-comments.py`, `check_mixin_freeze.py` |
| [`auto-tag.yml`](auto-tag.yml) | push to `main` (paths: `Orbit/**`, `.scripts/**`, `.pkgmeta`, `CHANGELOG.md`) | bumps minor, pushes `X.Y` tag |
| [`release.yml`](release.yml) | tag push `X.Y` / `X.Y.Z` / `X.Y-alpha.*` | bigwigs packager → curseforge (alpha or release channel by tag suffix) |
| [`alpha-release.yml`](alpha-release.yml) | manual (`workflow_dispatch`) | tags `ai-develop` HEAD as `X.Y-alpha.<timestamp>` |
| [`claude-issues.yml`](claude-issues.yml) | issue labeled `claude-approved` (owner only) | claude fixes the issue on `ai-develop`, maintains a rolling pr to `main` |

## versioning

`MAJOR.MINOR` — major is manual (`git tag -a 1.0 -m "..." && git push origin 1.0`), minor auto-bumps on every qualifying push to `main`. alpha tags are filtered out when computing the next stable version.

## secrets

| secret | used by | notes |
|---|---|---|
| `ORBIT_PAT` | `auto-tag.yml`, `alpha-release.yml` | personal access token. **required** — default `GITHUB_TOKEN` won't trigger downstream `release.yml` on tag push. |
| `CURSE_API_KEY` / `CF_API_KEY` | `release.yml` | curseforge upload auth |
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude-issues.yml` | generate via `claude setup-token`. consumes pro / max 5-hour quota — swap for `ANTHROPIC_API_KEY` if it bottlenecks. |
| `CLAUDE_RULES` | `claude-issues.yml` | trimmed copy of project rules (the local `CLAUDE.md` without sub-addon refs / slash commands). up to 48 KB. |

## claude issue resolver

**setup** (one-time):

1. create labels `claude-approved` and `claude-failed`.
2. create `ai-develop` branch — `git checkout -b ai-develop main && git push -u origin ai-develop`.
3. add secrets `CLAUDE_CODE_OAUTH_TOKEN` and `CLAUDE_RULES` (see above).
4. install [github.com/apps/claude](https://github.com/apps/claude) on the repo.
5. settings → actions → general → check "allow github actions to create and approve pull requests".

**flow**: label issue `claude-approved` → workflow gate (label + owner) → sync `ai-develop` ← `main` → claude commits `fix(#N): ...` → posts detail comment → upserts rolling pr `ai-develop → main` → removes label.

**failure path**: any step failure posts a comment with run url + likely causes and applies `claude-failed`. re-add `claude-approved` to retry.

**concurrency**: `claude-bot` group serializes runs.

**reverting**: `git revert <sha>` on `ai-develop` (fixes are direct commits, not per-issue branches).

## alpha publishing

manual trigger — **actions → alpha release → run workflow** (or `gh workflow run alpha-release.yml`). always tags `ai-develop` HEAD regardless of trigger context. `release.yml` then publishes to the curseforge alpha channel (skips `update_changelog.py` — changelog tracks stable only).

## common breakages

- **tag created but no release run** → `ORBIT_PAT` expired.
- **curseforge upload fails** → `CURSE_API_KEY` rotated.
- **claude run silently fails to start** → label gate not satisfied (must be repo owner adding `claude-approved`) or `CLAUDE_CODE_OAUTH_TOKEN` expired.
