import 'dart:convert';
import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;

import 'templates/claude_md_block.dart';
import 'templates/rewrite_sh.dart';

/// Outcome of a single `flart init --check` probe. Pretty-printed by the CLI
/// in a two-column ✓/✗ table; [hint] is only shown when [ok] is false.
class CheckResult {
  final String label;
  final bool ok;
  final String detail;
  final String? hint;
  const CheckResult({
    required this.label,
    required this.ok,
    required this.detail,
    this.hint,
  });
}

/// Resolves the XDG-compliant config home. Search order:
/// 1. `FLART_CONFIG_DIR` override (used by tests).
/// 2. `XDG_CONFIG_HOME`.
/// 3. `$HOME/.config`.
/// Throws [StateError] when none of the above are available (rare — only
/// happens on hosts without a HOME env, e.g. some CI sandboxes).
String resolveConfigHome(FlartEnv env) {
  for (final key in const ['FLART_CONFIG_DIR', 'XDG_CONFIG_HOME']) {
    final v = env.source[key]?.trim();
    if (v != null && v.isNotEmpty) return v;
  }
  final home = env.home;
  if (home == null) {
    throw StateError(
      'flart init: cannot resolve config dir — set HOME, XDG_CONFIG_HOME, '
      'or FLART_CONFIG_DIR.',
    );
  }
  return p.join(home, '.config');
}

/// Convenience: `<configHome>/flart/hooks/rewrite.sh`.
String defaultHookScriptPath(String configHome) =>
    p.join(configHome, 'flart', 'hooks', 'rewrite.sh');

/// Default Claude Code settings path: `~/.claude/settings.json`.
/// Test injection: pass an explicit value to [HookInstaller].
String defaultClaudeSettingsPath(FlartEnv env) {
  final home = env.home;
  if (home == null) {
    throw StateError(
      'flart init: \$HOME not set; cannot locate ~/.claude/settings.json.',
    );
  }
  return p.join(home, '.claude', 'settings.json');
}

/// Crash-safe write: emits to a sibling `<path>.tmp.<rand>` then atomically
/// renames over the target. Parent dirs are created as needed. When
/// [executable] is true (and not on Windows) the chmod runs on the tmp
/// file before the rename so the final inode is already executable.
void atomicWriteString(String path, String content,
    {bool executable = false}) {
  final tmp = '$path.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}';
  final tmpFile = File(tmp);
  tmpFile.parent.createSync(recursive: true);
  tmpFile.writeAsStringSync(content);
  if (executable && !Platform.isWindows) {
    Process.runSync('chmod', ['+x', tmp]);
  }
  tmpFile.renameSync(path);
}

/// Reads/writes the Claude Code `settings.json` to install or remove the
/// flart PreToolUse hook. Idempotent: re-running `install` updates the
/// command path if it changed; `uninstall` is a no-op when not installed.
///
/// **Savings DB is never touched by this class.** Uninstall removes only
/// the Claude Code integration (settings.json entry + hook script). Users
/// who want to wipe history use `flart savings --reset`.
class HookInstaller {
  final String settingsPath;
  final String hookScriptPath;

  const HookInstaller({
    required this.settingsPath,
    required this.hookScriptPath,
  });

  /// Writes the hook script + updates settings.json (atomic). Returns a
  /// short description of what changed (suitable for printing).
  List<String> installAll() {
    final messages = <String>[];
    messages.add(_writeHookScript());
    messages.add(_editSettings(install: true));
    return messages;
  }

  /// Removes the hook entry from settings.json AND deletes the hook script
  /// file (the inverse of installAll). Savings DB is **not** touched.
  List<String> uninstallAll() {
    final messages = <String>[_editSettings(install: false)];
    final script = File(hookScriptPath);
    if (script.existsSync()) {
      script.deleteSync();
      messages.add('Removed hook script $hookScriptPath');
    } else {
      messages.add('Hook script already absent ($hookScriptPath).');
    }
    return messages;
  }

  /// Multi-line status summary for `flart init --show`.
  String describeState() {
    final buf = StringBuffer();
    buf.writeln('Hook script:   '
        '${File(hookScriptPath).existsSync() ? "✓ $hookScriptPath" : "✗ not installed"}');
    final settingsFile = File(settingsPath);
    if (!settingsFile.existsSync()) {
      buf.write('settings.json: ✗ $settingsPath not found');
      return buf.toString();
    }
    final entry = _findFlartHookEntry(_loadSettings(settingsFile));
    if (entry == null) {
      buf.write('settings.json: ✗ no flart PreToolUse hook entry');
    } else {
      buf.write('settings.json: ✓ points to ${entry['command']}');
    }
    return buf.toString();
  }

  String _writeHookScript() {
    atomicWriteString(hookScriptPath, hookScriptTemplate, executable: true);
    return 'Wrote hook script to $hookScriptPath';
  }

  String _editSettings({required bool install}) {
    final file = File(settingsPath);
    if (!file.existsSync()) {
      if (!install) {
        return 'settings.json: nothing to remove ($settingsPath not present).';
      }
      file.parent.createSync(recursive: true);
      atomicWriteString(settingsPath, '{}\n');
    }
    final settings = _loadSettings(file);
    final hooksRoot = (settings['hooks'] is Map<String, dynamic>)
        ? settings['hooks'] as Map<String, dynamic>
        : <String, dynamic>{};
    final preToolUse =
        (hooksRoot['PreToolUse'] as List?)?.cast<dynamic>() ?? <dynamic>[];
    final preToolUseMutable = preToolUse.toList();

    final existingIndex = preToolUseMutable.indexWhere(_isFlartEntry);

    String action;
    if (install) {
      final newEntry = {
        'matcher': 'Bash',
        'hooks': [
          {'type': 'command', 'command': hookScriptPath},
        ],
      };
      if (existingIndex >= 0) {
        preToolUseMutable[existingIndex] = newEntry;
        action = 'Updated flart hook entry';
      } else {
        preToolUseMutable.add(newEntry);
        action = 'Installed flart hook entry';
      }
    } else {
      if (existingIndex < 0) {
        return 'settings.json: flart hook was not installed; nothing to do.';
      }
      preToolUseMutable.removeAt(existingIndex);
      action = 'Removed flart hook entry';
    }

    hooksRoot['PreToolUse'] = preToolUseMutable;
    settings['hooks'] = hooksRoot;

    final pretty = const JsonEncoder.withIndent('  ').convert(settings);
    atomicWriteString(settingsPath, '$pretty\n');
    return '$action in $settingsPath';
  }

  bool _isFlartEntry(dynamic e) {
    if (e is! Map) return false;
    if (e['matcher'] != 'Bash') return false;
    final hooks = e['hooks'];
    if (hooks is! List || hooks.isEmpty) return false;
    final h = hooks.first;
    return h is Map &&
        h['command'] is String &&
        (h['command'] as String).endsWith('/rewrite.sh');
  }

  Map<String, dynamic> _loadSettings(File file) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw FormatException(
        '$settingsPath: top-level JSON must be an object, got ${decoded.runtimeType}.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic>? _findFlartHookEntry(Map<String, dynamic> settings) {
    final hooks = settings['hooks'];
    if (hooks is! Map) return null;
    final preToolUse = hooks['PreToolUse'];
    if (preToolUse is! List) return null;
    for (final e in preToolUse) {
      if (_isFlartEntry(e)) {
        return Map<String, dynamic>.from((e as Map)['hooks'][0] as Map);
      }
    }
    return null;
  }
}

/// Installs/updates/removes the flart routing block in a project's CLAUDE.md.
/// Marker-based + atomic write so re-runs are idempotent and a crash mid-
/// write doesn't truncate the user's content.
class ProjectInstaller {
  final String claudeMdPath;
  const ProjectInstaller({required this.claudeMdPath});

  bool hasRoutingBlock() {
    final f = File(claudeMdPath);
    if (!f.existsSync()) return false;
    return f.readAsStringSync().contains(claudeMdMarkerStart);
  }

  /// Adds the routing block if absent, replaces it between markers if
  /// present. Returns the action description.
  String installRoutingBlock() {
    final file = File(claudeMdPath);
    if (!file.existsSync()) {
      atomicWriteString(claudeMdPath, '$claudeMdBlock\n');
      return 'Created $claudeMdPath with routing block.';
    }
    final existing = file.readAsStringSync();
    if (!existing.contains(claudeMdMarkerStart)) {
      final sep = existing.endsWith('\n') ? '\n' : '\n\n';
      atomicWriteString(claudeMdPath, '$existing$sep$claudeMdBlock\n');
      return 'Appended routing block to $claudeMdPath.';
    }
    final startIdx = existing.indexOf(claudeMdMarkerStart);
    final endIdx = existing.indexOf(claudeMdMarkerEnd, startIdx);
    if (endIdx < 0) {
      throw FormatException(
        '$claudeMdPath: opening marker present but closing marker missing. '
        'Remove the stale block manually and rerun.',
      );
    }
    final before = existing.substring(0, startIdx);
    final after = existing.substring(endIdx + claudeMdMarkerEnd.length);
    atomicWriteString(claudeMdPath, '$before$claudeMdBlock$after');
    return 'Updated routing block in $claudeMdPath.';
  }

  String removeRoutingBlock() {
    final file = File(claudeMdPath);
    if (!file.existsSync()) return 'CLAUDE.md not present; nothing to do.';
    final existing = file.readAsStringSync();
    final startIdx = existing.indexOf(claudeMdMarkerStart);
    if (startIdx < 0) {
      return 'No flart routing block in $claudeMdPath; nothing to do.';
    }
    final endIdx = existing.indexOf(claudeMdMarkerEnd, startIdx);
    if (endIdx < 0) {
      throw FormatException(
        '$claudeMdPath: stale start marker without end marker. Fix by hand.',
      );
    }
    var before = existing.substring(0, startIdx);
    var after = existing.substring(endIdx + claudeMdMarkerEnd.length);
    before = before.replaceFirst(RegExp(r'\n*$'), '');
    after = after.replaceFirst(RegExp(r'^\n*'), '');
    final next = '${before.isEmpty ? '' : '$before\n'}'
        '${after.isEmpty ? '' : '\n$after'}';
    if (next.trim().isEmpty) {
      file.deleteSync();
      return 'Removed routing block; $claudeMdPath was otherwise empty and has been deleted.';
    }
    atomicWriteString(
      claudeMdPath,
      next.endsWith('\n') ? next : '$next\n',
    );
    return 'Removed routing block from $claudeMdPath.';
  }
}

/// `flart init --check` diagnostics. Returns a `CheckResult` per probe so
/// the CLI can render a stable ✓/✗ table with actionable hints.
class HookChecker {
  final Future<String?> Function(String exe) _whichExe;

  HookChecker({Future<String?> Function(String exe)? whichExe})
      : _whichExe = whichExe ?? _defaultWhich;

  Future<List<CheckResult>> diagnose({
    required String settingsPath,
    required String hookScriptPath,
    String? projectClaudeMdPath,
  }) async {
    final results = <CheckResult>[];

    final flartPath = await _whichExe('flart');
    results.add(CheckResult(
      label: 'flart binary',
      ok: flartPath != null,
      detail: flartPath ?? 'not found in PATH',
      hint: flartPath == null
          ? 'Move the compiled binary to a directory on \$PATH '
              '(e.g. ~/.local/bin) and reopen your shell.'
          : null,
    ));

    final jqPath = await _whichExe('jq');
    results.add(CheckResult(
      label: 'jq',
      ok: jqPath != null,
      detail: jqPath ?? 'not found',
      hint: jqPath == null
          ? 'Install: brew install jq (macOS) or apt install jq (Linux).'
          : null,
    ));

    final settingsFile = File(settingsPath);
    if (!settingsFile.existsSync()) {
      results.add(CheckResult(
        label: 'Claude Code settings.json',
        ok: false,
        detail: '$settingsPath not present',
        hint: 'Run `flart init --global` to install the hook entry '
            '(creates the file if missing).',
      ));
    } else {
      try {
        jsonDecode(settingsFile.readAsStringSync());
        results.add(CheckResult(
          label: 'Claude Code settings.json',
          ok: true,
          detail: settingsPath,
        ));
      } on FormatException catch (e) {
        results.add(CheckResult(
          label: 'Claude Code settings.json',
          ok: false,
          detail: 'invalid JSON: ${e.message}',
          hint: 'Fix or remove $settingsPath and rerun `flart init`.',
        ));
      }
    }

    final scriptInstalled = File(hookScriptPath).existsSync();
    results.add(CheckResult(
      label: 'Hook script',
      ok: scriptInstalled,
      detail: scriptInstalled ? hookScriptPath : 'not installed',
      hint: scriptInstalled
          ? null
          : 'Run `flart init --global` to write it.',
    ));

    if (projectClaudeMdPath != null) {
      final cmFile = File(projectClaudeMdPath);
      final hasMarker = cmFile.existsSync() &&
          cmFile.readAsStringSync().contains(claudeMdMarkerStart);
      results.add(CheckResult(
        label: 'CLAUDE.md routing',
        ok: hasMarker,
        detail: hasMarker
            ? projectClaudeMdPath
            : (cmFile.existsSync()
                ? '$projectClaudeMdPath (no flart marker)'
                : '$projectClaudeMdPath not present'),
        hint: hasMarker ? null : 'Run `flart init --project`.',
      ));
    }

    return results;
  }

  /// Returns the absolute path of [exe] on PATH, or `null` when not found.
  static Future<String?> _defaultWhich(String exe) async {
    try {
      final r = await Process.run('which', [exe]);
      if (r.exitCode != 0) return null;
      final out = (r.stdout as String).trim();
      return out.isEmpty ? null : out;
    } on ProcessException {
      return null;
    }
  }
}

/// Renders [CheckResult]s into a 2-column ✓/✗ table with hints under each
/// failed row. Used by both `flart init --check` and `--show`.
String renderCheckTable(List<CheckResult> results) {
  if (results.isEmpty) return 'No checks ran.';
  final labelWidth = results
      .map((r) => r.label.length)
      .fold<int>(0, (m, v) => v > m ? v : m);
  final buf = StringBuffer();
  for (final r in results) {
    final mark = r.ok ? '✓' : '✗';
    buf.writeln('$mark ${r.label.padRight(labelWidth)}  ${r.detail}');
    if (!r.ok && r.hint != null) {
      buf.writeln('${' ' * (labelWidth + 4)}→ ${r.hint}');
    }
  }
  return buf.toString().trimRight();
}
