# Changelog

All notable changes to flart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-05-19

Follow-up release after v0.1.0 Wonderous validation. Two themes: better
defaults for the savings report (most users wanted the current project's
number first), and a way to nudge spawned sub-agents toward flart
commands without rewriting their prompts by hand.

### Added

- **PreToolUse / Task hook.** `flart init` now installs a second hook
  entry alongside the Bash matcher. When the parent agent spawns a
  sub-agent via the Task tool, the hook records the activation in
  `subagent_activations` (new SQLite table, migration v2) and emits
  `hookSpecificOutput.additionalContext` carrying a short flart usage
  reminder that Claude Code merges into the sub-agent prompt. Script:
  `~/.config/flart/hooks/task_hook.sh` → `flart task-hook` (hidden
  subcommand). Soft-fails when `flart` isn't on PATH.
- **`flart savings --all`** for the old cumulative-across-projects view.
- **`flart savings --project-path=<path>`** for explicit project
  scoping (e.g. inspecting another checkout from elsewhere).
- **`subagent_activations` count** in `flart savings` text output
  (headline line, only shown when > 0) and JSON output
  (`summary.subagent_activations`, always present).

### Changed

- **`flart savings` default scope.** Without flags, the report now
  scopes to the current project's `pubspec.yaml` root instead of the
  all-projects total. Running outside any Flutter/Dart project falls
  back to `--all` automatically with an explanatory note on stderr.
- **`flart init` preview text** lists both hook scripts (Bash + Task)
  and mentions the sub-agent context injection. `--show` reports the
  install status of both scripts and entries; `--check` adds a fifth
  probe for the Task script.
- **CLAUDE.md routing block** gains a one-line mention that sub-agents
  inherit the same routing automatically.

### Deprecated

- **`flart savings --project`** (boolean flag) is deprecated. It still
  scopes to the current project (equivalent to the new default) but
  prints a deprecation warning on stderr. To be removed in v0.3.0.
  Replacement: just call `flart savings` (default), or use
  `--project-path=<path>` for explicit scoping.

### Schema

- Migration **v2** adds `subagent_activations(id, timestamp,
  project_path, parent_session_id)` plus two indexes
  (`idx_subagent_timestamp`, `idx_subagent_project`). Additive only —
  existing `invocations` table and indexes are untouched.

### Decision log

- **Read/Grep/Edit matchers deliberately excluded.** Claude Code's hook
  API would support intercepting these, but: (a) silent truncation of
  Read causes the agent to make decisions on missing content; (b)
  PostToolUse can only add feedback, not replace output, so any
  filtering happens *before* the tool runs which is blind to the actual
  result; (c) the token savings rarely outweigh the iteration cost. May
  revisit in a future opt-in beta. See README "Frequently
  misunderstood".
- **`SubagentStart` event not used.** Listed in some Claude Code
  releases but currently unstable (GH issue #27755 settings.json
  trigger failures, #19170 schema gaps). `PreToolUse` matcher `Task`
  is dokumante and stable in v2.0.10+; it fires when the parent invokes
  the Task tool, and the injected `additionalContext` is what reaches
  the sub-agent.

### Internal

- 9 new tests: 4 for `SubagentActivationRepo`, 5 for `flart task-hook`,
  7 for savings scope, 3 new installer tests, 2 for task-hook template
  defaults, plus formatter coverage for the new fields.
- Plan / decision log: [`flart_PLAN.md`](./flart_PLAN.md) v1.14.

[0.2.0]: https://github.com/MelihCevhertas/flart/releases/tag/v0.2.0

## [0.1.0] — 2026-05-19 (first public release)

First usable release. Targets macOS (Apple Silicon) + Linux (x64), Dart
3.11.5 / Flutter 3.41.9. Promoted from `v0.1.0-rc1` after a real Claude
Code agent-session measurement on Wonderous (see Performance below).

### Added — flart_core (infrastructure)

- YAML config loader with global + project merge, env-var overrides
  (`FLART_DATA_DIR`, `FLART_CONFIG_DIR`, `FLART_NO_SAVINGS`, `FLART_CONFIG`),
  XDG-compliant default paths.
- SQLite savings store with WAL/`busy_timeout` pragmas, additive migration
  system, UTC-canonical timestamps.
- `TokenEstimator`, `SafeTruncator` (UTF-8 + line-boundary safe),
  `TeeManager` (failure-mode tee with rotation), level-based `Logger`.

### Added — flart_executor

- `SandboxExecutor` running scripts in `dart`, `bash`, `python`, `node`.
  Bounded output (head+tail ring buffer), manual SIGTERM→SIGKILL timeout
  (default 2s grace), stdin closed up-front so reader-scripts don't hang,
  stream drain + cancel after `exitCode` resolves (fixes the orphan-child
  pipe-FD inheritance footgun).
- Dart mod-A import validator (`package:` / relative rejected).
- Dart auto-wrap: top-level code wraps in `void main()` automatically;
  imports get lifted out of the wrap.
- `--file` and `--stdin` input modes for the CLI.

### Added — flart_filters (13 filters)

- `analyze` — `dart analyze --format=machine` grouped by rule;
  truncate-long-messages applied.
- `test` — Flutter / pure-Dart auto-detected; JSON event stream collapsed
  to `PASSED N/N` or per-failure detail.
- `build apk|web|ipa` — single class, success extracts `✓ Built <path>`,
  failure surfaces compile error block + `BUILD FAILED` summary.
- `clean`, `format`, `doctor`, `devices`, `gen-l10n`, `compile`.
- `pub get`, `pub upgrade`, `pub outdated` (JSON default + text fallback),
  `pub deps` (direct deps by default, `--tree` for full).
- `fix` — rule-summary collapse (`<rule> [N in M files]`); `--apply`
  preserved.
- `err` and `test-wrap` — generic command wrappers (marker + stack frame
  extraction; pass/fail count parsing).
- `FilterRunner` (in flart_cli): tee on failure, savings DB write, anti-
  bloat fallback so filtered output is never larger than raw.

### Added — flart_savings (reporter)

- `Aggregator` (read-only SQL): summary, by-module, by-command,
  by-project, top-N, recent-N details, daily buckets.
- Formatters: text (token-first headline), JSON (stable schema), CSV
  (single denormalised table), graph (Unicode block bar chart).
- `flart savings` CLI with `--since`/`--until`, `--project`, `--by-*`,
  `--top`, `--details`, `--json`/`--csv`/`--graph`, `--reset` (with `--force`
  for CI). Friendly "no data yet" when the DB is empty.

### Added — flart_hooks (Claude Code integration)

- `CommandRewriter`: 21 native→flart rules, `cd ... && rest` preserved,
  pipes/redirects/backgrounding all passthrough.
- `flart rewrite "<cmd>"` CLI: pure function exposed for the bash hook.
- Bash hook script template (16 lines, soft-fails when `flart` or `jq`
  aren't on PATH).
- CLAUDE.md routing block template with marker-based idempotency
  (`<!-- flart-routing-start --> ... <!-- flart-routing-end -->`).
- `flart init` CLI: `--global`, `--project`, `--show`, `--check`,
  `--uninstall`, `--yes`. Confirmation prompt + atomic writes for
  `settings.json` / hook script / CLAUDE.md. Uninstall never touches the
  savings DB.

### Performance

**Real Claude Code agent-session on Wonderous (rc1 validation, 30-min
task):** 11 invocations across analyze / fix / build / test → 82.6 KB raw
→ 1.4 KB filtered. **98.3% reduction, ~21,807 tokens saved.** The agent
went from 47 analyzer warnings to 0 (91 fixes across 54 files); hook +
routing + tee all engaged end-to-end. Per-command savings: analyze 98.5%
(7×), fix 97.1% (2×), build 92.6% (1×), test 48.5% (1× — zero-test run).

**Per-invocation measurements** across three projects (Wonderous,
flutter_todos, this workspace, 17 captures): ~91% average. Highlights:

- `flart analyze` (Wonderous): 19,836 → 257 B (98.7%)
- `flart test` (flutter_todos, 144 tests): 105,593 → 29 B (99.97%)
- `flart fix` (Wonderous, 92 fixes across 55 files): 5,772 → 189 B (96.7%)
- `flart pub deps` (Wonderous): 16,181 → 997 B (93.8%)
- `flart build apk --release` (fresh app): 750 → 85 B (88.7%)

Binary size: ~7.0 MB (`dart compile exe`, macOS arm64). Section 18 target
was <30 MB.

### Known limitations

- Windows is untested. CI matrix is macOS arm64 + Linux x64 only. v0.2.0.
- Intel Mac (`macos-13`) not in the binary release — GitHub Actions Intel
  runners are 50+ min queued. Build from source per README Limitations.
  v0.2.0.
- `fvm`-wrapped commands (`fvm flutter analyze`) are not rewritten. Use
  shell aliases for flutter/dart, or wait for v0.2.0.
- `flutter run` (interactive hot-reload) is not wrapped.
- iOS `ipa` builds are filter-ready but not measured in this release.
- Token counts are estimates (±15% relative to Anthropic's actual
  tokenizer). Byte counts are exact.

### Internal

- 334 unit + integration tests across 6 packages.
- Two fixture pipelines: `tools/generate_fixtures.sh` (auto, 14 files)
  and manual captures with full-context headers (13 files for build /
  doctor / fix / etc.).
- Plan / decision log: [`flart_PLAN.md`](./flart_PLAN.md) v1.13.

[0.1.0]: https://github.com/MelihCevhertas/flart/releases/tag/v0.1.0
