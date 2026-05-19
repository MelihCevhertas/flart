/// PostToolUse / Bash hook script template — written to
/// `<configHome>/flart/hooks/bash_post_hook.sh` by `flart init` when the
/// detected Claude Code version supports `hookSpecificOutput.updatedToolOutput`
/// (v2.1.121+). Plan v1.15 §7.6.
///
/// Wired into Claude Code as `PostToolUse` with matcher `Bash`. After the
/// agent's shell command runs, this script reads the hook input on stdin
/// and execs `flart bash-post-hook`, which:
///   - decides whether to bypass or mutate based on output size + bypass rules
///     (see `bash_post_filter.dart` decision tree),
///   - tees the raw output for the recovery path,
///   - records the invocation in `invocations` (module = `bash_post`) when
///     mutation actually saved bytes,
///   - emits the JSON response with `updatedToolOutput` + `additionalContext`.
///
/// Soft-fail: if `flart` is missing from PATH the script exits 0 silently and
/// the agent sees the raw bash output unchanged (graceful degrade).
const String bashPostHookScriptTemplate = r'''#!/usr/bin/env bash
# flart PostToolUse / Bash hook — installed by `flart init` on Claude Code
# v2.1.121+. Re-installs are idempotent: rerun `flart init` to refresh.
set -e

if ! command -v flart >/dev/null 2>&1; then exit 0; fi
exec flart bash-post-hook
''';
