import 'dart:convert';
import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;

import 'templates/claude_md_block.dart';
import 'templates/rewrite_sh.dart';
import 'templates/task_hook_sh.dart';

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

/// Convenience: `<configHome>/flart/hooks/task_hook.sh` — PreToolUse/Task
/// companion to `rewrite.sh`. Added in v0.2.0.
String defaultTaskHookScriptPath(String configHome) =>
    p.join(configHome, 'flart', 'hooks', 'task_hook.sh');

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
/// flart PreToolUse hooks. As of v0.2.0 manages two entries:
///   - matcher `Bash` → rewrite.sh (command auto-rewrite)
///   - matcher `Task` → task_hook.sh (sub-agent context injection)
/// Idempotent: re-running `install` updates command paths; `uninstall` is a
/// no-op when not installed.
///
/// **Savings DB is never touched by this class.** Uninstall removes only the
/// Claude Code integration (settings.json entries + hook scripts). Users who
/// want to wipe history use `flart savings --reset`.
class HookInstaller {
  final String settingsPath;
  final String hookScriptPath;
  final String taskHookScriptPath;

  const HookInstaller({
    required this.settingsPath,
    required this.hookScriptPath,
    required this.taskHookScriptPath,
  });

  /// Writes both hook scripts + updates settings.json (atomic). Returns a
  /// short description of what changed (suitable for printing).
  List<String> installAll() {
    final messages = <String>[];
    messages.add(_writeScript(hookScriptPath, hookScriptTemplate));
    messages.add(_writeScript(taskHookScriptPath, taskHookScriptTemplate));
    messages.add(_editSettings(install: true));
    return messages;
  }

  /// Removes both flart entries from settings.json AND deletes the hook
  /// script files (the inverse of installAll). Savings DB is **not** touched.
  List<String> uninstallAll() {
    final messages = <String>[_editSettings(install: false)];
    for (final path in [hookScriptPath, taskHookScriptPath]) {
      final script = File(path);
      if (script.existsSync()) {
        script.deleteSync();
        messages.add('Removed hook script $path');
      } else {
        messages.add('Hook script already absent ($path).');
      }
    }
    return messages;
  }

  /// Multi-line status summary for `flart init --show`.
  String describeState() {
    final buf = StringBuffer();
    buf.writeln('Hook script (Bash): '
        '${File(hookScriptPath).existsSync() ? "✓ $hookScriptPath" : "✗ not installed"}');
    buf.writeln('Hook script (Task): '
        '${File(taskHookScriptPath).existsSync() ? "✓ $taskHookScriptPath" : "✗ not installed"}');
    final settingsFile = File(settingsPath);
    if (!settingsFile.existsSync()) {
      buf.write('settings.json:      ✗ $settingsPath not found');
      return buf.toString();
    }
    final settings = _loadSettings(settingsFile);
    final bashEntry = _findFlartEntry(settings, matcher: 'Bash');
    final taskEntry = _findFlartEntry(settings, matcher: 'Task');
    buf.writeln(bashEntry == null
        ? 'settings.json (Bash): ✗ no flart entry'
        : 'settings.json (Bash): ✓ points to ${bashEntry['command']}');
    buf.write(taskEntry == null
        ? 'settings.json (Task): ✗ no flart entry'
        : 'settings.json (Task): ✓ points to ${taskEntry['command']}');
    return buf.toString();
  }

  String _writeScript(String path, String content) {
    atomicWriteString(path, content, executable: true);
    return 'Wrote hook script to $path';
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
    final mutable = preToolUse.toList();

    final actions = <String>[];
    for (final pair in [
      _MatcherSpec(matcher: 'Bash', scriptPath: hookScriptPath),
      _MatcherSpec(matcher: 'Task', scriptPath: taskHookScriptPath),
    ]) {
      final existingIndex = mutable.indexWhere(
          (e) => _isFlartEntryFor(e, matcher: pair.matcher));
      if (install) {
        final newEntry = {
          'matcher': pair.matcher,
          'hooks': [
            {'type': 'command', 'command': pair.scriptPath},
          ],
        };
        if (existingIndex >= 0) {
          mutable[existingIndex] = newEntry;
          actions.add('updated ${pair.matcher} hook');
        } else {
          mutable.add(newEntry);
          actions.add('installed ${pair.matcher} hook');
        }
      } else {
        if (existingIndex >= 0) {
          mutable.removeAt(existingIndex);
          actions.add('removed ${pair.matcher} hook');
        }
      }
    }

    if (actions.isEmpty) {
      return 'settings.json: no flart entries; nothing to do.';
    }

    hooksRoot['PreToolUse'] = mutable;
    settings['hooks'] = hooksRoot;

    final pretty = const JsonEncoder.withIndent('  ').convert(settings);
    atomicWriteString(settingsPath, '$pretty\n');
    return 'settings.json: ${actions.join(', ')}.';
  }

  /// True when [e] is a flart entry for the given matcher. Recognised by
  /// the hooks[0].command ending in `/rewrite.sh` (Bash) or `/task_hook.sh`
  /// (Task) — same convention the installer uses on write.
  bool _isFlartEntryFor(dynamic e, {required String matcher}) {
    if (e is! Map) return false;
    if (e['matcher'] != matcher) return false;
    final hooks = e['hooks'];
    if (hooks is! List || hooks.isEmpty) return false;
    final h = hooks.first;
    if (h is! Map || h['command'] is! String) return false;
    final cmd = h['command'] as String;
    if (matcher == 'Bash') return cmd.endsWith('/rewrite.sh');
    if (matcher == 'Task') return cmd.endsWith('/task_hook.sh');
    return false;
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

  Map<String, dynamic>? _findFlartEntry(
    Map<String, dynamic> settings, {
    required String matcher,
  }) {
    final hooks = settings['hooks'];
    if (hooks is! Map) return null;
    final preToolUse = hooks['PreToolUse'];
    if (preToolUse is! List) return null;
    for (final e in preToolUse) {
      if (_isFlartEntryFor(e, matcher: matcher)) {
        return Map<String, dynamic>.from((e as Map)['hooks'][0] as Map);
      }
    }
    return null;
  }
}

class _MatcherSpec {
  final String matcher;
  final String scriptPath;
  const _MatcherSpec({required this.matcher, required this.scriptPath});
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
    String? taskHookScriptPath,
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
        hint: 'Run `flart init --global` to install the hook entries '
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
      label: 'Hook script (Bash)',
      ok: scriptInstalled,
      detail: scriptInstalled ? hookScriptPath : 'not installed',
      hint: scriptInstalled
          ? null
          : 'Run `flart init --global` to write it.',
    ));

    if (taskHookScriptPath != null) {
      final taskInstalled = File(taskHookScriptPath).existsSync();
      results.add(CheckResult(
        label: 'Hook script (Task)',
        ok: taskInstalled,
        detail: taskInstalled ? taskHookScriptPath : 'not installed',
        hint: taskInstalled
            ? null
            : 'Run `flart init --global` to write it.',
      ));
    }

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
