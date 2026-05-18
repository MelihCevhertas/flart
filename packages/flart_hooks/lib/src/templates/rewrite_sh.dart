/// Bash hook script template — written to `<dataDir>/hooks/rewrite.sh` by
/// `flart init`. Plan Section 7.2.
///
/// Kept intentionally thin: all rewrite logic lives in `flart rewrite`. The
/// script handles only the Claude Code hook protocol (stdin JSON in, JSON
/// out with `permissionDecision: "allow"` + updated tool input).
///
/// Two soft-fail bailouts: if `flart` or `jq` aren't on PATH the script
/// exits 0 silently so the user's bash invocation flows through unchanged.
const String hookScriptTemplate = r'''#!/usr/bin/env bash
# flart PreToolUse hook — installed by `flart init`.
# Re-installs are idempotent: rerun `flart init` to refresh.
set -e

if ! command -v flart >/dev/null 2>&1; then exit 0; fi
if ! command -v jq    >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -z "$CMD" ] && exit 0

REWRITTEN=$(flart rewrite "$CMD" 2>/dev/null) || exit 0
[ "$CMD" = "$REWRITTEN" ] && exit 0

jq -c --arg cmd "$REWRITTEN" \
  '.tool_input.command = $cmd | {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "flart auto-rewrite",
      updatedInput: .tool_input
    }
  }' <<<"$INPUT"
''';
