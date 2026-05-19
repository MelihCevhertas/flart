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

> Status: **v0.3.0 — Bash output mutation + sub-agent context + CWD savings.**
> macOS (Apple Silicon) + Linux (x64). Single binary, no runtime
> dependencies beyond Dart/Flutter and `jq` (for the Bash rewrite hook).
> The new PostToolUse / Bash output mutation requires **Claude Code
> v2.1.121+**; older Claude versions still get the PreToolUse rewrite +
> sub-agent context but skip output mutation cleanly. Intel Mac, Windows,
> and `fvm` support still deferred — Intel Mac users can build from
> source (see [Limitations](#limitations)). The interim v0.2.0 tag was
> rolled back on 2026-05-19 and its contents merged into this release.

---

## What it does

Three paradigms in one binary:

1. **Reactive filters.** A PreToolUse / Bash hook rewrites `flutter
   analyze` → `flart analyze`, `flutter test` → `flart test`, etc. The
   wrapped command runs as normal, but its output is parsed and emitted
   in a compact form — only the lines the agent actually needs to act
   on.

2. **Generic Bash output mutation (v0.3.0, Claude Code v2.1.121+).** A
   PostToolUse / Bash hook filters output from raw shell commands
   (`grep`, `find`, `python -c`, custom scripts) the agent runs but
   flart doesn't have a dedicated filter for. Decision tree: ≤30 lines
   → passthrough, 31–200 → head 20 + tail 5, > 200 → head 15 + tail 5 +
   error grep, exit ≠ 0 → framed error with stderr + stdout tail. Full
   raw output teed for recovery (`cat` of the tee log auto-passes
   through, or use the `FLART_FULL_OUTPUT=1` env prefix).

3. **Sandbox executor.** Instead of asking the agent to read 30 files
   to answer "how many providers does this app have?", let it write a
   one-liner: `flart exec dart 'print(Directory("lib").listSync(...))'`.
   The script runs in a temp dir, output is capped, only the result
   lands in context.

A SQLite-backed savings tracker records every invocation (filter,
executor, bash_post) so you can run `flart savings` and see exactly how
much agent context the tool has saved you, scoped to the current
project by default. A separate `subagent_activations` table counts
Task-tool sub-agent spawns that received flart's routing reminder.

---

## Install

### From a release (preferred)

```bash
curl -fsSL https://raw.githubusercontent.com/MelihCevhertas/flart/main/install.sh | sh
```

Detects your OS/arch (macOS arm64/x64, Linux x64), downloads the matching
binary into `~/.local/bin/flart` (override with `FLART_INSTALL_DIR`), and
reminds you to add `~/.local/bin` to your `$PATH` if it isn't already
there. Pin a specific release with `FLART_VERSION=v0.3.0`. The hook is
**not** installed automatically — run `flart init` once when you're ready.

> The PostToolUse / Bash output mutation requires **Claude Code
> v2.1.121+** (`updatedToolOutput` was introduced there). The
> PreToolUse rewrite and Task-hook context injection work on any Claude
> Code build; `flart init` detects the installed version and skips the
> PostToolUse entry on older releases with an explanatory note.

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
flart version          # flart 0.3.0 (commit <sha>)
flart init --check     # ✓/✗ table: PATH, jq, Claude Code version,
                       # settings.json, three hook scripts (Bash PreToolUse,
                       # Task PreToolUse, Bash PostToolUse if supported)

# 2. Install the Claude Code hook + project routing.
cd ~/your/flutter/project
flart init             # prompts before touching ~/.claude/settings.json
                       # use --yes for CI/non-interactive flows

# 3. Try it.
flart analyze
flart savings          # current project's savings since the DB was created
flart savings --all    # cumulative across every project flart has ever seen
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

> **v0.3.0 default changed.** `flart savings` (no flags) now scopes to
> the current project's `pubspec.yaml` root instead of the all-projects
> total — most users wanted the local number first. Pass `--all` to get
> the old cumulative report. Running outside any Flutter/Dart project
> falls back to `--all` automatically with a note. The boolean
> `--project` flag is deprecated and will be removed in v0.4.0; use the
> default scope (current project) or `--project-path=<path>` for an
> explicit override.

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
| `flart savings [flags...]`             | —                                    | Default = current project. Flags: `--all`, `--project-path=<path>`, `--by-command`, `--by-module`, `--top`, `--details`, `--since`, `--until`, `--json`, `--csv`, `--graph`, `--reset`. |
| `flart init [flags...]`                | —                                    | Install/inspect the three Claude Code hooks + CLAUDE.md routing block. PostToolUse / Bash entry is gated on Claude Code v2.1.121+. |
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

> The 98.3% figure is from v0.1.0 — pre-PostToolUse/Bash. v0.3.0 adds a
> second compression surface (raw shell commands the agent runs:
> `grep`, `find`, `python -c`, custom scripts) that wasn't part of the
> original measurement. A fresh agent-session measurement covering the
> v0.3.0 surface area is on the v0.4.0 backlog.

Reproduce on your own project:

```bash
flart init                  # install the three Claude Code hooks
# ...have a normal coding session with the agent...
flart savings --by-command  # see your numbers
flart savings --by-module   # filter vs bash_post vs executor breakdown
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

flart wires into three Claude Code hook events. `flart init --global`
writes the hook scripts and the settings.json entries; re-running is
idempotent.

1. **PreToolUse / Bash → command rewrite.**
   `~/.config/flart/hooks/rewrite.sh`. When Claude Code is about to run a
   bash command, the hook reads the command from stdin, pipes it through
   `flart rewrite`, and (if the command is mapped) returns a
   `permissionDecision: "allow"` payload with the rewritten command —
   no per-call permission prompt. Unmapped commands flow through normally
   so output redirection stays where the user put it.

2. **PreToolUse / Task → sub-agent context.**
   `~/.config/flart/hooks/task_hook.sh`. When the parent agent spawns a
   sub-agent via the Task tool, the hook records the activation in the
   `subagent_activations` table and returns
   `hookSpecificOutput.additionalContext` — a short flart usage reminder
   that Claude Code merges into the sub-agent's prompt so it knows to
   prefer `flart analyze` / `flart test` / `flart exec` over raw
   `flutter` and `dart` calls.

3. **PostToolUse / Bash → output mutation (Claude Code v2.1.121+).**
   `~/.config/flart/hooks/bash_post_hook.sh`. After the agent's shell
   command runs, the hook reads `tool_response.stdout` + `stderr`, runs
   `BashPostFilter`, optionally rewrites the response via
   `hookSpecificOutput.updatedToolOutput`, and tees the full output to
   `~/.local/share/flart/tee/<epoch>_<slug>_bash.log`. Decision tree:

   | Condition                                                 | Behaviour     |
   | --------------------------------------------------------- | ------------- |
   | Empty output                                              | passthrough   |
   | Command starts with `flart …` (cd-prefix aware)           | passthrough   |
   | Command contains `FLART_FULL_OUTPUT=1`                    | passthrough (explicit) |
   | First token in `cat/head/tail/less/more/wc/grep` + arg under tee dir | passthrough (recovery) |
   | Exit 0 + ≤ 30 lines                                       | passthrough   |
   | Exit 0 + 31–200 lines                                     | head 20 + tail 5 + tee path |
   | Exit 0 + > 200 lines                                      | head 15 + tail 5 + error grep + tee path |
   | Exit ≠ 0 + substantial output                             | framed `Command failed (exit N)` + stderr (≤ 2 KB) + stdout tail (20 lines) + tee path |
   | Any branch where the framed output would exceed raw bytes | passthrough (anti-bloat) |

4. **`flart rewrite`** is a pure Dart function. Pipes, redirects,
   backgrounding (`&`) and chained commands (`;`) all bail to passthrough.

5. **Filters** in `flart_filters/` are pure transforms:
   `(stdout, stderr, exitCode) → (compact text, metadata, was_truncated)`.
   They never spawn processes. That happens in `FilterRunner` (CLI layer),
   which also handles the tee dump on failure and the SQLite tracking
   write. The PostToolUse / Bash filter follows the same anti-bloat
   contract — never produces more bytes than the raw command did.

6. **Savings DB** lives at `~/.local/share/flart/savings.db`. Rows:
   - `invocations` (one per flart subcommand invocation OR per
     PostToolUse / Bash mutation; `module` column distinguishes
     `filter`, `executor`, and `bash_post`).
   - `subagent_activations` (one per Task hook fire — counter only, no
     byte/token savings tracked).

### What flart deliberately doesn't intercept

`PreToolUse` would let us mutate the input of any Claude Code tool,
including Read, Grep, Edit, and Write. We don't. The hook surface area
is restricted to **Bash** (input + output) and **Task** (sub-agent
context). The reasoning:

- **Read.** Truncating file content causes silent agent confusion: the
  agent assumes it saw the full file and makes wrong decisions about
  line references, function boundaries, and call sites.
- **Grep.** The agent already chooses between `mode: "files_with_matches"`
  and `mode: "content"` based on the question it's answering. Imposing
  a filter on top would override that deliberate choice.
- **Edit / Write.** The input is already the agent's own draft — there
  is nothing to filter that the agent didn't just produce. Mutating it
  would corrupt their work.
- **PostToolUse for Read/Grep/Edit/Write.** Claude Code's PostToolUse
  hook can add a system reminder via `additionalContext` but cannot
  swap the tool result the agent reads (output mutation is a PreToolUse
  capability for *some* tools and a per-event opt-in elsewhere). For
  Bash specifically, v2.1.121+ added `updatedToolOutput` on PostToolUse —
  that's what powers the new filter.

We may revisit Read/Grep in a future opt-in beta once we have data on
where the agent benefits from compression vs where it suffers from
missing context.

### Frequently misunderstood

**Q: Does the sub-agent context injection cost tokens?**

A: Yes — the `additionalContext` text (~300 chars / ~80 tokens) is
prepended to every sub-agent prompt. We keep it intentionally short.
It's recorded in `subagent_activations` as a counter only; the savings
report shows the number of activations but no byte/token "savings"
because there is no measurable raw-vs-filtered comparison for context
injection.

**Q: What happens to a `cat`/`head`/`tail` of the tee log?**

A: Bypassed by the PostToolUse filter. The decision tree's `tee-read`
rule catches reads of any file under `~/.local/share/flart/tee/`, so the
recovery path (agent fetches the full log explicitly) doesn't loop back
through the filter. Belt-and-braces escape: prefix the command with
`FLART_FULL_OUTPUT=1` and it also passes through.

**Q: I'm on Claude Code < 2.1.121. What still works?**

A: PreToolUse / Bash (command rewrite) and PreToolUse / Task (sub-agent
context). The PostToolUse / Bash output mutation is gated on v2.1.121+
because `hookSpecificOutput.updatedToolOutput` doesn't exist before
that. `flart init` reports the version it detected and skips the
PostToolUse install without erroring; upgrade Claude Code and re-run
`flart init` to enable it.

---

## Limitations

- **Claude Code < v2.1.121 misses output mutation.** PreToolUse / Bash
  (command rewrite) and PreToolUse / Task (sub-agent context) work on
  every Claude Code build, but the PostToolUse / Bash output filter
  needs `hookSpecificOutput.updatedToolOutput`, which lands in v2.1.121.
  `flart init` detects the version and skips the PostToolUse entry on
  older releases — no half-install state, just a missing feature.
- **Windows untested.** Code paths are mostly portable, but no CI run
  on Windows yet. On a future-release backlog; no firm version target.
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

- **`fvm` not supported.** `fvm flutter analyze` flows through unchanged.
  Workaround: alias `flutter` and `dart` to your fvm shims, or wait for
  the v1.1 wrapper-aware rewrite.
- **`flutter run` not wrapped.** Interactive hot-reload mode is hard to
  filter without changing semantics. v1.1.
- **iOS `ipa` builds not measured.** The filter is generic enough to
  handle Xcode output but a Mac-with-signing test environment is harder
  to reproduce on CI.
- **Token counts are estimates.** ±15% relative to Anthropic's actual
  tokenizer. Byte counts are exact.
- **Hook auto-allows mapped commands.** The Claude Code permission
  prompt is bypassed for the subset `flart rewrite` matches. Everything
  else (git, npm, gh, …) still goes through the normal permission flow.
- **Output mutation only covers Bash.** Read, Grep, Edit, and Write are
  deliberately not intercepted — see
  [What flart deliberately doesn't intercept](#what-flart-deliberately-doesnt-intercept)
  for the reasoning.

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
