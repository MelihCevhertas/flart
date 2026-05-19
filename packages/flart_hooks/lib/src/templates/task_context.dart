/// `additionalContext` injected into every sub-agent spawned via the Task
/// tool. Returned as part of the PreToolUse / Task hook JSON response.
///
/// Kept short on purpose — Claude Code merges this into the sub-agent system
/// prompt verbatim; every byte costs the sub-agent context window. Aim is to
/// nudge the sub-agent toward flart commands when it's about to shell out for
/// Flutter/Dart work, not to retrain it on the full routing table (the
/// project CLAUDE.md handles that for both parent and child).
const String taskAdditionalContext =
    'Sub-agent being spawned. flart is available for Flutter/Dart work in '
    'this environment. Prefer: flart analyze, flart test, flart fix --apply, '
    "flart build, flart pub get. For wrapping bash/python/dart: flart exec "
    "<lang> '<code>'. Tool output is automatically compressed.";
