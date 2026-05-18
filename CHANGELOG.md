# Changelog

All notable changes to flart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-XX (first public release)

First usable release. Targets macOS + Linux, Dart 3.11.5 / Flutter 3.41.9.

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

Average across 17 measurements on three real projects (Wonderous,
flutter_todos, this workspace): **~91% reduction in agent-visible
bytes/tokens**. Highlights:

- `flart analyze` (Wonderous): 19,836 → 257 B (98.7%)
- `flart test` (flutter_todos, 144 tests): 105,593 → 29 B (99.97%)
- `flart fix` (Wonderous, 92 fixes across 55 files): 5,772 → 189 B (96.7%)
- `flart pub deps` (Wonderous): 16,181 → 997 B (93.8%)
- `flart build apk --release` (fresh app): 750 → 85 B (88.7%)

Binary size: ~7.0 MB (`dart compile exe`, macOS arm64). Section 18 target
was <30 MB.

### Known limitations

- Windows is untested. CI matrix is mac+linux only.
- `fvm`-wrapped commands (`fvm flutter analyze`) are not rewritten. Use
  shell aliases for flutter/dart, or wait for v1.1.
- `flutter run` (interactive hot-reload) is not wrapped.
- iOS `ipa` builds are filter-ready but not measured in this release.
- Token counts are estimates (±15% relative to Anthropic's actual
  tokenizer). Byte counts are exact.

### Internal

- 334 unit + integration tests across 6 packages.
- Two fixture pipelines: `tools/generate_fixtures.sh` (auto, 14 files)
  and manual captures with full-context headers (13 files for build /
  doctor / fix / etc.).
- Plan / decision log: [`flart_PLAN.md`](./flart_PLAN.md) v1.8.

[0.1.0]: https://github.com/MelihCevhertas/flart/releases/tag/v0.1.0
