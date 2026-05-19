/// Task hook script template — written to `<configHome>/flart/hooks/task_hook.sh`
/// by `flart init`. Companion to `rewrite.sh`. Plan v1.14 §7.5.
///
/// Wired into Claude Code as `PreToolUse` with matcher `Task`. When the parent
/// agent invokes the Task tool to spawn a sub-agent, this script reads the
/// hook input on stdin and execs `flart task-hook`, which:
///   - records the activation in `subagent_activations` (best-effort),
///   - emits the `hookSpecificOutput.additionalContext` JSON that Claude Code
///     injects into the sub-agent's prompt.
///
/// Soft-fail: if `flart` is missing from PATH the script exits 0 silently and
/// Claude Code spawns the sub-agent without flart context (graceful degrade).
const String taskHookScriptTemplate = r'''#!/usr/bin/env bash
# flart PreToolUse / Task hook — installed by `flart init`.
# Re-installs are idempotent: rerun `flart init` to refresh.
set -e

if ! command -v flart >/dev/null 2>&1; then exit 0; fi
exec flart task-hook
''';
