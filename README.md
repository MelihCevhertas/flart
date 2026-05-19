# flart

**Token-optimization for Flutter/Dart development with Claude Code.**

`flart` wraps the Flutter/Dart commands Claude Code calls and compacts their
output before it reaches the agent's context. A `flutter analyze` run that
prints 20 KB of warnings becomes a 200-byte summary; a `flutter test` JSON
event stream becomes one `PASSED N/N` line; a `flutter build` failure
preserves the actual compile errors while dropping Gradle daemon spam.

Validated inside a real Claude Code session on the open-source
[Wonderous](https://github.com/gskinnerTeam/flutter-wonderous-app) Flutter
app: across 11 invocations spanning `analyze`, `fix`, `build`, and `test`,
flart compressed 82.6 KB of tool output down to 1.4 KB — a **98.3%
reduction (~21,807 tokens saved)** while the agent fixed 47 real warnings
to zero. See [Real-world measurement](#real-world-measurement) for the
per-command breakdown. Per-invocation numbers across other projects sit
in [Typical savings](#typical-savings); your real-session savings depend
on command mix and hook adoption.

> Status: **v0.2.0 — sub-agent context + CWD-scoped savings.** macOS
> (Apple Silicon) + Linux (x64). Single binary, no runtime dependencies
> beyond Dart/Flutter and `jq` (for the Bash hook). Intel Mac, Windows,
> and `fvm` support still deferred — Intel Mac users can build from
> source (see [Limitations](#limitations)). What changed in v0.2.0:
> [CHANGELOG](./CHANGELOG.md).

---

## What it does

Two paradigms in one binary:

1. **Reactive filters.** A PreToolUse hook rewrites `flutter analyze` →
   `flart analyze`, `flutter test` → `flart test`, etc. The wrapped command
   runs as normal, but its output is parsed and emitted in a compact form
   — only the lines the agent actually needs to act on.

2. **Sandbox executor.** Instead of asking the agent to read 30 files to
   answer "how many providers does this app have?", let it write a one-liner:
   `flart exec dart 'print(Directory("lib").listSync(recursive: true)...)'`.
   The script runs in a temp dir, output is capped, only the result lands
   in context.

A SQLite-backed savings tracker records every invocation so you can run
`flart savings` and see exactly how much agent context the tool has saved
you across all projects.

---

## Install

> The install script is part of the v0.1.0 release artefact; until the
> first GitHub release is published, use the from-source path below.

### From a release (preferred)

```bash
curl -fsSL https://raw.githubusercontent.com/MelihCevhertas/flart/main/install.sh | sh
```

Detects your OS/arch (macOS arm64/x64, Linux x64), downloads the matching
binary into `~/.local/bin/flart` (override with `FLART_INSTALL_DIR`), and
reminds you to add `~/.local/bin` to your `$PATH` if it isn't already
there. Pin a specific release with `FLART_VERSION=v0.1.0`. The hook is
**not** installed automatically — run `flart init` once when you're ready.

> **macOS Gatekeeper:** the installer clears the `com.apple.quarantine`
> attribute proactively, but if you ever see *"flart cannot be opened
> because the developer cannot be verified"*, run
> `xattr -d com.apple.quarantine ~/.local/bin/flart` (or right-click →
> Open in Finder once).

### From source (requires Dart 3.5+)

```bash
git clone https://github.com/MelihCevhertas/flart.git
cd flart
dart pub get
dart compile exe packages/flart_cli/bin/flart.dart -o ~/.local/bin/flart
flart version
```

You also need `jq` on `$PATH` for the Claude Code hook itself
(`brew install jq` / `apt install jq`).

---

## Quick start

```bash
# 1. Verify install.
which flart
flart version          # flart 0.1.0 (commit <sha>)
flart init --check     # ✓/✗ table: PATH, jq, settings.json, hook script

# 2. Install the Claude Code hook + project routing.
cd ~/your/flutter/project
flart init             # prompts before touching ~/.claude/settings.json
                       # use --yes for CI/non-interactive flows

# 3. Try it.
flart analyze
flart savings          # ~91% saved so far
```

Hook installs are idempotent — re-running `flart init` updates the entry
in place. To remove it: `flart init --uninstall` (savings DB is **never**
touched by uninstall; clear history separately with
`flart savings --reset`).

### Verifying savings

The numbers in the [Typical savings](#typical-savings) table are
per-invocation measurements I (the author) captured against real projects.
Your real-world session savings depend on command mix (analyze-heavy runs
compress better than format-heavy ones) and hook adoption (commands the
agent runs by name vs by path). To read your own:

```bash
flart savings                # current project (CWD scope) by default
flart savings --all          # cumulative across every recorded project
flart savings --project-path=/path/to/project   # explicit path
flart savings --by-command   # per-command compression table
flart savings --since 7d     # last week
flart savings --details      # most recent invocations with raw/filtered bytes
flart savings --json         # machine-readable; pipe through jq for custom views
```

> **v0.2.0 default changed.** `flart savings` (no flags) now scopes to
> the current project's `pubspec.yaml` root instead of the all-projects
> total — most users wanted the local number first. Pass `--all` to get
> the old cumulative report. Running outside any Flutter/Dart project
> falls back to `--all` automatically with a note.

Empty database? Run a few flart commands first (e.g. `flart analyze` in a
project with a `pubspec.yaml`).

---

## Commands

| Command                                | Wraps                                | Notes                                                                    |
| -------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------ |
| `flart analyze [paths...]`             | `dart analyze --format=machine`      | Groups warnings by rule; truncates long messages (`truncate_long_messages_at`). |
| `flart test [paths...]`                | `flutter test` / `dart test --reporter=json` | Auto-detects Flutter vs pure-Dart pubspec. Surfaces failures only. |
| `flart build apk\|web\|ipa [args...]`  | `flutter build <target>`             | Compact success line + size; failures keep compile errors, full log tee'd to disk. |
| `flart pub get [args...]`              | `flutter pub get` / `dart pub get`   | Total deps from `pubspec.lock` + changed list (`+`/`~`/`-`).            |
| `flart pub upgrade [args...]`          | `flutter pub upgrade`                | Upgraded packages only; drops `>` informational lines.                  |
| `flart pub outdated [args...]`         | `flutter pub outdated --json`        | Only packages where `current != latest`. Text fallback with `--no-json`. |
| `flart pub deps [args...]`             | `flutter pub deps`                   | Direct deps only by default; `--tree` for full ASCII tree.              |
| `flart format [paths...]`              | `dart format`                        | Changed files + summary; drops "Unchanged …" rows.                      |
| `flart fix [--apply]`                  | `dart fix --dry-run` / `--apply`     | Rule-summary collapse: `<rule> [N in M files]`.                         |
| `flart clean`                          | `flutter clean`                      | Collapses Gradle spam to `ok`.                                          |
| `flart doctor`                         | `flutter doctor`                     | `[✓]` categories collapsed; `[!]`/`[✗]` kept with detail.               |
| `flart devices`                        | `flutter devices`                    | Just the device rows; drops footer.                                     |
| `flart gen-l10n`                       | `flutter gen-l10n`                   | Generated path + untranslated keys grouped per locale.                  |
| `flart compile <target> [args...]`     | `dart compile exe\|js\|...`          | One-line success or stderr block on failure.                            |
| `flart exec <runtime> <code\|--file\|--stdin>` | sandboxed `dart`/`bash`/`python`/`node` | Bounded output (head+tail), 60s timeout, optional `--max-output`. |
| `flart err <command...>`               | any                                  | Generic wrapper that surfaces only error markers + stack frames.        |
| `flart test-wrap <command...>`         | any                                  | Generic test summary extractor (passed/failed counts).                  |
| `flart rewrite "<cmd>"`                | —                                    | Pure function: what the PreToolUse hook would substitute.               |
| `flart savings [flags...]`             | —                                    | Reports: default, `--by-command`, `--by-module`, `--top`, `--details`, `--json`, `--csv`, `--graph`, `--reset`. |
| `flart init [flags...]`                | —                                    | Install/inspect the Claude Code hook + CLAUDE.md routing block.         |
| `flart version`                        | —                                    | Semver + commit SHA.                                                    |

---

## Real-world measurement

We ran flart against the open-source Wonderous Flutter app inside a fresh
Claude Code session (30-minute task: clean up analyzer warnings, run
tests, attempt a release build). The agent invoked flart 11 times across
4 command types and ended with 47 warnings → 0, applying 91 fixes across
54 files. The hook engaged, CLAUDE.md routing worked end-to-end, and the
tee mechanism was used by the agent to retrieve full output on failure.

**Aggregate:** 82.6 KB raw tool output → 1.4 KB filtered. **98.3%
reduction, ~21,807 tokens saved.**

| Command         | Invocations | % saved |
| --------------- | ----------: | ------: |
| `flart analyze` |           7 |    98.5 |
| `flart fix`     |           2 |    97.1 |
| `flart build`   |           1 |    92.6 |
| `flart test`    |           1 |    48.5 |

`flart test` shows lower compression because the run had **zero tests**
(small raw output, fixed-size summary header). Failure scenarios were
exercised too: a `flart build` against the project's NDK-missing config
surfaced the actual error line while dropping Gradle daemon spam.

Reproduce on your own project:

```bash
flart init                  # install the Claude Code hook
# ...have a normal coding session with the agent...
flart savings --by-command  # see your numbers
```

---

## Typical savings

Measured by `flart savings` against real projects. Token estimates use
`chars / 3.8` (configurable, ±15% relative to Anthropic's actual
tokenizer). Byte counts are exact.

| Command             | Project          | Raw bytes | Filtered bytes | % saved |
| ------------------- | ---------------- | --------: | -------------: | ------: |
| `flart analyze`     | Wonderous        |    19,836 |            257 |  **98.7** |
| `flart test`        | flutter_todos    |   105,593 |             29 | **99.97** |
| `flart fix`         | Wonderous        |     5,772 |            189 |  **96.7** |
| `flart build apk`   | flart_test_app   |       463 |             73 |  **84.2** |
| `flart build apk --release` | flart_test_app |     750 |             85 |  **88.7** |
| `flart pub get`     | Wonderous        |       736 |             24 |    96.7 |
| `flart pub upgrade` | Wonderous        |       743 |             21 |    97.2 |
| `flart pub outdated`| Wonderous        |     5,710 |            634 |    88.9 |
| `flart pub deps`    | Wonderous        |    16,181 |            997 |    93.8 |
| `flart format lib/` | Wonderous        |    12,292 |             53 |    99.6 |
| `flart gen-l10n`    | Wonderous        |       158 |              2 |    98.7 |
| `flart clean`       | Wonderous        |       729 |              2 |    99.7 |
| `flart doctor`      | (host)           |       514 |            235 |    54.3 |
| `flart devices`     | (host)           |       599 |            184 |    69.3 |

Caveats — included as data, not hidden:

- **`flart doctor` ~54%** on a healthy host. `flutter doctor` already
  produces a compact 10-line summary; the filter mostly collapses the
  `[✓]` rows but doesn't have much room to compress further.
- **`flart compile exe` ≈0%** by design. Modern `dart compile` is one
  line (`Generated: <path>`). FilterRunner's anti-bloat fallback hands
  the raw line straight through.
- **`flart build apk --debug` ~84%** on a fresh app. Production builds
  with multi-target apk and asset processing should see higher savings;
  release builds already nudge it to ~89% on a tiny app.

---

## Configuration

flart reads `~/.config/flart/config.yaml` (global) and merges
`<project>/.flart/config.yaml` over it. Defaults are sensible — most
users never need to touch this file.

```yaml
token_estimation:
  chars_per_token: 3.8         # English+code average; 3.5 for Turkish
  estimated_deviation: 0.15    # ±15% — surfaced in report disclaimers

tee:
  enabled: true                # Failures → ~/.local/share/flart/tee/*.log
  mode: failures               # failures | always | never
  max_files: 30
  min_size_bytes: 500

filters:
  truncate_long_messages_at: 300   # Per-error message cap (analyze/test/build)
  max_failures_shown: 15
  max_warnings_shown: 50

executor:
  timeout_seconds: 60
  max_output_bytes: 65536
  head_ratio: 0.6              # 60% head, 40% tail when output overflows
  allowed_runtimes: [dart, bash, python, javascript]

savings:
  enabled: true                # FLART_NO_SAVINGS=1 to suppress per-invocation

log:
  level: info                  # debug | info | warn | error
```

Environment overrides:

- `FLART_DATA_DIR` — savings DB + tee directory (default `~/.local/share/flart/`)
- `FLART_CONFIG_DIR` — hook script location (default XDG `~/.config/`)
- `FLART_NO_SAVINGS=1` — skip writing to the savings DB
- `FLART_CONFIG` — explicit global config path

---

## How it works

1. **PreToolUse / Bash hook.** `flart init --global` writes
   `~/.config/flart/hooks/rewrite.sh` and adds a `Bash` matcher entry to
   `~/.claude/settings.json`. When Claude Code is about to run a bash
   command, the hook reads the command from stdin, pipes it through
   `flart rewrite`, and (if the command is mapped) returns a
   `permissionDecision: "allow"` payload with the rewritten command —
   no per-call permission prompt.

2. **PreToolUse / Task hook (v0.2.0).** A second entry uses matcher
   `Task` and points to `~/.config/flart/hooks/task_hook.sh`. When the
   parent agent spawns a sub-agent via the Task tool, the hook records
   the activation in `subagent_activations` and returns
   `hookSpecificOutput.additionalContext` — a short flart usage hint
   that Claude Code merges into the sub-agent's prompt so it knows to
   prefer `flart analyze`/`flart test`/`flart exec` over raw `flutter`
   and `dart` calls.

3. **`flart rewrite`** is a pure Dart function. Pipes, redirects,
   backgrounding (`&`) and chained commands (`;`) all bail to passthrough
   so output redirection stays where the user put it.

4. **Filters** are pure transforms: `(stdout, stderr, exitCode) →
   (compact text, metadata, was_truncated)`. They never spawn processes.
   That happens in `FilterRunner` (CLI layer), which also handles the
   tee dump on failure and the SQLite tracking write.

5. **Savings DB** lives at `~/.local/share/flart/savings.db`. One row per
   invocation in `invocations` (byte/char/token counts, exit code,
   duration, optional tee path) and one row per sub-agent spawn in
   `subagent_activations` (timestamp, project path, parent session id).
   `flart savings` aggregates both.

6. **Anti-bloat fallback.** If a filter happens to produce *more* bytes
   than the raw command did, FilterRunner reverts to raw. So the agent
   never pays a worse cost than the unwrapped command would have charged
   — at most equal, usually a small fraction.

### Frequently misunderstood

**Q: Why doesn't flart intercept Claude Code's Read/Grep tools?**

A: We can, technically — PreToolUse supports those matchers. We
deliberately don't. Truncating Read output causes silent agent
confusion: the agent assumes it saw the full file and makes wrong
decisions. The token savings rarely outweigh the iteration cost or
correctness risk. PostToolUse can't modify output at all (only add
feedback). We may reconsider in a future version with an opt-in beta
once we have more usage data.

**Q: Does the sub-agent context injection cost tokens?**

A: Yes — the `additionalContext` text (~300 chars / ~80 tokens) is
prepended to every sub-agent prompt. We keep it intentionally short.
It's recorded in `subagent_activations` as a counter only; the savings
report shows the number of activations but no byte/token "savings"
because there is no measurable raw-vs-filtered comparison for context
injection.

---

## Limitations

- **Windows untested.** Code paths are mostly portable, but no CI run
  on Windows yet. v0.2.0.
- **macOS Intel x64 not in binary release.** GitHub Actions Intel Mac
  runners (`macos-13`) sit in queue for 50+ minutes, which is incompatible
  with the rapid release cadence. Apple Silicon is the install target;
  Intel Mac users can build from source:

  ```bash
  git clone https://github.com/MelihCevhertas/flart.git
  cd flart
  dart pub get
  dart compile exe packages/flart_cli/bin/flart.dart -o flart
  sudo mv flart /usr/local/bin/
  ```

  Tracked for v0.2.0 alongside Windows.
- **`fvm` not supported.** `fvm flutter analyze` flows through unchanged.
  Workaround: alias `flutter` and `dart` to your fvm shims, or wait for
  v1.1's wrapper-aware rewrite.
- **`flutter run` not wrapped.** Interactive hot-reload mode is hard to
  filter without changing semantics. v1.1.
- **iOS `ipa` builds not measured.** The filter is generic enough to
  handle Xcode output but Mac-with-signing test environment is harder to
  reproduce on CI.
- **Token counts are estimates.** ±15% relative to Anthropic's actual
  tokenizer. Byte counts are exact.
- **Hook auto-allows mapped commands.** The Claude Code permission
  prompt is bypassed for the subset `flart rewrite` matches. Everything
  else (git, npm, gh, …) still goes through the normal permission flow.
- **Tool output mutation is read-only.** Claude Code's `PostToolUse`
  hook can add feedback but cannot replace the tool output the agent
  sees. flart only intercepts at the `PreToolUse` boundary (rewriting
  the command before it runs, or injecting sub-agent context before the
  spawn). We will not silently truncate Read/Grep output (see
  [Frequently misunderstood](#frequently-misunderstood)).

---

## Development

Workspace layout (Dart 3.5+ pure pub workspaces, no melos):

```
packages/
├── flart_core/       # Config, SQLite, truncation, tee, logging, token estimator
├── flart_executor/   # Sandbox runner (dart/bash/python/node)
├── flart_filters/    # 13 command filters + CommandFilter base
├── flart_savings/    # Aggregator + 4 formatters (text/json/csv/graph)
├── flart_hooks/      # rewrite logic + Claude Code installer
└── flart_cli/        # Entry point, command dispatch, FilterRunner
```

Useful commands:

```bash
tools/test_all.sh                            # Run every package's tests
dart test --exclude-tags=integration         # Fast inner loop (per package)
tools/generate_fixtures.sh                   # Refresh auto-generated fixtures
dart compile exe packages/flart_cli/bin/flart.dart -o flart
```

The fixture suite has two kinds of files under
`packages/flart_filters/test/fixtures/`:

- **Auto-generated** (14) — `tools/generate_fixtures.sh` builds a tmp
  Dart package, runs the real command, captures + sanitises output.
- **Manual** (13) — `flutter build`, `dart fix`, `flutter doctor`, etc.
  Too slow or host-dependent to regenerate on every test run; each
  file's header documents how to re-capture it.

Plan / roadmap / decision log: `flart_PLAN.md`.

---

## License

MIT. See `LICENSE`.

## Links

- Repository: <https://github.com/MelihCevhertas/flart>
- Roadmap and design log: [`flart_PLAN.md`](./flart_PLAN.md)
