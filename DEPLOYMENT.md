# Deployment — flart v0.1.0

Step-by-step handoff for Melih to take the local v0.1.0-rc1 build through
the GitHub release pipeline + real-agent measurement → v0.1.0 final.

The Release Candidate pattern is intentional: ship a `-rc1` tag first,
run the agent-session measurement against the published artefacts, then
either promote to `v0.1.0` (good numbers) or iterate to `-rc2` (bug
found). See Plan v1.9 changelog entry.

---

## Pre-flight (this session — already done)

- ✅ Git repo initialised, remote set to `MelihCevhertas/flart`
- ✅ Initial commit `599c666` — flart v0.1.0 (Faz 1-7 complete)
- ✅ Local `flart-macos-arm64` binary built with full version stamp
  (`flart 0.1.0-rc1 (commit 599c666, built 2026-05-18)`)
- ✅ install.sh OS/arch detect verified (404 expected — release doesn't
  exist yet)
- ✅ 334 tests pass, `dart analyze` clean, README/CHANGELOG drafted

---

## Step 1 — Push the baseline to GitHub

```bash
cd ~/Documents/flart
git log --oneline           # should show 599c666 only
git push -u origin main
```

CI `.github/workflows/test.yml` will trigger on push. **Wait for the
green checkmark** before tagging — if mac or ubuntu fails, fix locally,
amend the commit, force-push, retry.

If the GitHub repo doesn't exist yet:

```bash
gh repo create MelihCevhertas/flart --public \
  --description "Token-optimization CLI for Flutter/Dart with Claude Code" \
  --source=. --remote=origin --push
```

(Requires `gh` CLI authenticated; alternatively create the empty repo via
the web UI and `git push -u origin main` afterwards.)

---

## Step 2 — Tag the release candidate

Tag locally, push the tag → `release.yml` will build three binaries
(`flart-macos-arm64`, `flart-macos-x64`, `flart-linux-x64`) and create a
**draft** GitHub release with the binaries attached.

```bash
git tag -a v0.1.0-rc1 -m "v0.1.0-rc1: release candidate for agent-session verification"
git push origin v0.1.0-rc1
```

Watch the run at <https://github.com/MelihCevhertas/flart/actions> — all
three matrix jobs need to go green. Each job smoke-tests its own binary
via `./<asset> version + help`.

When the workflow finishes, a draft release appears at
`https://github.com/MelihCevhertas/flart/releases`. Inspect it:

- 3 binaries attached (correct asset names)
- Each binary's `version` output matches `flart 0.1.0-rc1 (commit 599c666, built YYYY-MM-DD)`
- Auto-generated release notes look sensible

Keep the release in draft mode for now — promote to published only
after agent measurement.

---

## Step 3 — Test install.sh against the real release

Once the draft has the artefacts, the install URL works:

```bash
# In a fresh terminal (so PATH state is clean):
curl -fsSL https://raw.githubusercontent.com/MelihCevhertas/flart/main/install.sh \
  | FLART_VERSION=v0.1.0-rc1 sh
```

Expected:
- `→ Downloading flart-macos-arm64 from https://github.com/MelihCevhertas/flart/releases/download/v0.1.0-rc1`
- `→ Installed ~/.local/bin/flart`
- macOS quarantine attribute cleared silently
- PATH hint if `~/.local/bin` isn't on `$PATH`
- `flart 0.1.0-rc1 (commit 599c666, built YYYY-MM-DD)` printed at the end

If the binary fails to launch on macOS with "developer cannot be
verified", run the printed remediation:

```bash
xattr -d com.apple.quarantine ~/.local/bin/flart
```

---

## Step 4 — Agent-session measurement (the real test)

This is the v0.1.0 quality gate. The goal: verify the PreToolUse hook
actually intercepts agent commands and produces real savings.

Setup:

```bash
cd /tmp
rm -rf wonderous
git clone --depth=1 https://github.com/gskinnerTeam/flutter-wonderous-app.git wonderous
cd wonderous
flutter pub get
flart init --check     # ✓ on all 5 rows (flart, jq, settings.json, hook, CLAUDE.md if scope=project)
flart init             # confirm prompt, install global + project routing
```

Open a **fresh Claude Code session** in `/tmp/wonderous`. Give the agent
a 30-minute task that exercises analyse/test/build workflows. Suggested
prompt:

> Look at `lib/ui/screens/artifact_carousel/` and report:
> 1. Refactor opportunities (any unused widgets, prop drilling, magic numbers).
> 2. Run `flutter analyze` and triage the warnings.
> 3. Run `flutter test` (or note if tests are absent) and report status.
> 4. Suggest 2-3 concrete improvements with file:line references.
> Don't apply changes — just analysis + recommendations.

Let the agent run free for 30 minutes. Don't intervene.

Measurement:

```bash
flart savings                          # token totals + by-command breakdown
sqlite3 ~/.local/share/flart/savings.db <<SQL
  SELECT command, COUNT(*) AS calls,
         SUM(raw_bytes) AS raw,
         SUM(filtered_bytes) AS filt
  FROM invocations
  WHERE timestamp >= strftime('%s', 'now', '-2 hours')
  GROUP BY command
  ORDER BY (raw - filt) DESC;
SQL
```

Also inspect the Claude Code hook log (if you keep one) to verify the
hook actually fired — look for `flart auto-rewrite` decisions on Bash
tool calls.

Expected ranges (Plan F):
- Filter savings (analyze/test/build/etc.): **85–95% per invocation**
- Executor adoption: **0–30%** (agent habits favour Read+Grep at first)
- Total session savings: **40–65%**

If the numbers land in those bands, you've shipped. If they don't:

- Hook never fired → check `~/.claude/settings.json` has the flart entry,
  `which flart`, `which jq`, run `flart init --check`.
- Rewrite logic wrong → reproduce the agent's command, run
  `flart rewrite "<cmd>"` directly.
- Savings tracker empty → check `~/.local/share/flart/savings.db` (or
  `$FLART_DATA_DIR/savings.db` if you set the env).

Patch, commit, tag `v0.1.0-rc2`, repeat from Step 2.

---

## Step 5 — Promote to v0.1.0

Once agent measurement is satisfactory:

1. Update README with the real session number ("Measured agent session
   on Wonderous, 30 min: X% reduction in agent-visible bytes").
2. Update CHANGELOG release date (`2026-05-XX` → actual day).
3. Commit the README/CHANGELOG polish.
4. Tag `v0.1.0`:

   ```bash
   git tag -a v0.1.0 -m "v0.1.0: first public release"
   git push origin v0.1.0
   ```

5. Wait for the release workflow. Draft release appears at
   `releases/v0.1.0`. Compare its binaries to the rc1 binaries (versions
   should differ only by the FLART_VERSION stamp).
6. Edit the draft, paste an excerpt of the CHANGELOG into the release
   notes, **Publish release**.
7. Announce. The `install.sh` URL (`releases/latest/download/...`) now
   serves v0.1.0 automatically.

---

## Rollback / iteration

If you need to roll back a tag:

```bash
git tag -d v0.1.0-rcN
git push origin :refs/tags/v0.1.0-rcN
# Delete the draft release in the GitHub UI.
```

If a published release ships a regression, prefer a follow-up patch
release (`v0.1.1`) over deleting the tag — published artefacts may
already be cached by users.
