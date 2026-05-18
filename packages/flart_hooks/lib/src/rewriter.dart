/// Pure command-string rewriter used by `flart rewrite` and (via that
/// subcommand) the Claude Code PreToolUse hook. Plan Section 7.4.
///
/// Contract:
/// - [rewrite] takes the raw bash command Claude Code is about to run and
///   returns the rewritten form (or the original when no rule applies or
///   shell features make rewriting unsafe).
/// - No I/O, no Process spawning. Hook-friendly purity.
///
/// Safety rules (return original on any of these):
/// - Pipe (`|`), redirect (`>`, `>>`, `<`, `2>`, `&>`), background (`&` at
///   end), or `;` chaining anywhere except a leading `cd ... &&`.
/// - Wrapped invocations we don't recognise (e.g. `fvm flutter analyze`) —
///   v1.1+ adds an fvm passthrough table.
class CommandRewriter {
  /// Compact pairs of `<native command prefix>` → `<flart command prefix>`.
  /// Order matters: longer prefixes first so `flutter pub get` is matched
  /// before `flutter`.
  static const List<List<String>> _rules = [
    ['flutter pub get', 'flart pub get'],
    ['flutter pub upgrade', 'flart pub upgrade'],
    ['flutter pub outdated', 'flart pub outdated'],
    ['flutter pub deps', 'flart pub deps'],
    ['flutter build apk', 'flart build apk'],
    ['flutter build web', 'flart build web'],
    ['flutter build ipa', 'flart build ipa'],
    ['flutter test', 'flart test'],
    ['flutter analyze', 'flart analyze'],
    ['flutter clean', 'flart clean'],
    ['flutter doctor', 'flart doctor'],
    ['flutter devices', 'flart devices'],
    ['flutter gen-l10n', 'flart gen-l10n'],
    ['dart analyze', 'flart analyze'],
    ['dart format', 'flart format'],
    ['dart fix --apply', 'flart fix --apply'],
    ['dart fix', 'flart fix'],
    ['dart compile exe', 'flart compile exe'],
    ['dart compile aot-snapshot', 'flart compile aot-snapshot'],
    ['dart compile jit-snapshot', 'flart compile jit-snapshot'],
    ['dart compile js', 'flart compile js'],
    ['dart compile kernel', 'flart compile kernel'],
  ];

  /// Pipe/redirect/chaining markers that disqualify a command. `&` is
  /// handled separately below via a token check (regex `\b&\b` doesn't fire
  /// when `&` is surrounded by whitespace).
  static final RegExp _unsafeShellOps = RegExp(r'(\||>>|>|<|;)');

  /// `cd <path> && <rest>` — leading-cd preservation. Captures path and rest.
  static final RegExp _leadingCdRegex =
      RegExp(r'^\s*(cd\s+[^&;|]+?)\s*&&\s*(.+)$');

  /// Rewrite a raw command. Returns the rewritten form, or the input
  /// unchanged when no rule applies or shell features make rewrite unsafe.
  String rewrite(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return input;

    // Leading `cd ... && rest` — strip cd, rewrite rest, re-attach.
    final cdMatch = _leadingCdRegex.firstMatch(trimmed);
    if (cdMatch != null) {
      final cdPart = cdMatch.group(1)!;
      final rest = cdMatch.group(2)!;
      final rewrittenRest = _rewriteSingle(rest);
      if (rewrittenRest == rest) return input;
      return '$cdPart && $rewrittenRest';
    }

    return _rewriteSingle(trimmed) == trimmed
        ? input
        : _rewriteSingle(trimmed);
  }

  String _rewriteSingle(String cmd) {
    // Safety: bail on pipes/redirects/chaining/backgrounding. The token
    // check catches `cmd &` (background) and `cmd & cmd2` (chain) without
    // false-firing on `&&` (which is split out at the cd step above).
    if (_unsafeShellOps.hasMatch(cmd)) return cmd;
    if (cmd.split(RegExp(r'\s+')).contains('&')) return cmd;
    for (final pair in _rules) {
      final native = pair[0];
      final flart = pair[1];
      if (cmd == native) return flart;
      if (cmd.startsWith('$native ')) {
        return '$flart${cmd.substring(native.length)}';
      }
    }
    return cmd;
  }
}
