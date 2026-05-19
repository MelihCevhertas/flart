import 'dart:convert';
import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;

import 'claude_version.dart';
import 'templates/bash_post_hook_sh.dart';
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
/// companion to `rewrite.sh`. Added in v0.2.0 (released as part of v0.3.0).
String defaultTaskHookScriptPath(String configHome) =>
    p.join(configHome, 'flart', 'hooks', 'task_hook.sh');

/// Convenience: `<configHome>/flart/hooks/bash_post_hook.sh` —
/// PostToolUse/Bash companion. Added in v0.3.0 (requires Claude Code v2.1.121+).
String defaultBashPostHookScriptPath(String configHome) =>
    p.join(configHome, 'flart', 'hooks', 'bash_post_hook.sh');

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
/// flart hooks. As of v0.3.0 manages up to three entries:
///   - PreToolUse  / matcher `Bash` → rewrite.sh        (command auto-rewrite)
///   - PreToolUse  / matcher `Task` → task_hook.sh      (sub-agent context)
///   - PostToolUse / matcher `Bash` → bash_post_hook.sh (output mutation)
///
/// The PostToolUse entry requires Claude Code v2.1.121+ for
/// `hookSpecificOutput.updatedToolOutput`. When [claudeVersion] is older or
/// unknown, that entry is *skipped on install* and *still removed on
/// uninstall* (cleanly purges stale entries from older flart installs).
/// `installAll` reports the skip in its message list so the CLI surfaces it.
///
/// **Savings DB is never touched by this class.** Uninstall removes only the
/// Claude Code integration (settings.json entries + hook scripts). Users who
/// want to wipe history use `flart savings --reset`.
class HookInstaller {
  final String settingsPath;
  final String hookScriptPath;
  final String taskHookScriptPath;
  final String bashPostHookScriptPath;

  /// Detected Claude Code version. `null` means we couldn't probe (binary
  /// missing / parse failure); we conservatively skip PostToolUse in that
  /// case and let the user re-run after fixing PATH.
  final ClaudeCodeVersion? claudeVersion;

  const HookInstaller({
    required this.settingsPath,
    required this.hookScriptPath,
    required this.taskHookScriptPath,
    required this.bashPostHookScriptPath,
    this.claudeVersion,
  });

  bool get _postToolUseEnabled =>
      claudeVersion != null && claudeVersion!.supportsOutputMutation;

  /// Writes hook scripts + updates settings.json (atomic). The PostToolUse
  /// script + entry are only written when [claudeVersion] is at or above
  /// v2.1.121; older versions get an explanatory note in the returned list.
  List<String> installAll() {
    final messages = <String>[];
    messages.add(_writeScript(hookScriptPath, hookScriptTemplate));
    messages.add(_writeScript(taskHookScriptPath, taskHookScriptTemplate));
    if (_postToolUseEnabled) {
      messages.add(_writeScript(bashPostHookScriptPath, bashPostHookScriptTemplate));
    } else {
      messages.add(
        'PostToolUse/Bash hook skipped: requires Claude Code '
        '${ClaudeCodeVersion.outputMutationMinimum}+, detected '
        '${claudeVersion?.toString() ?? 'unknown (claude binary not on PATH?)'}. '
        'Upgrade Claude Code and rerun `flart init` to enable output mutation.',
      );
    }
    messages.add(_editSettings(install: true));
    return messages;
  }

  /// Removes every flart entry from settings.json AND deletes the hook
  /// script files (the inverse of installAll). Removes the PostToolUse
  /// entry even when [claudeVersion] is below the threshold — old installs
  /// may still have it on disk from a prior upgrade.
  List<String> uninstallAll() {
    final messages = <String>[_editSettings(install: false)];
    for (final path in [hookScriptPath, taskHookScriptPath, bashPostHookScriptPath]) {
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
    buf.writeln('Claude Code:        '
        '${claudeVersion == null ? "✗ unknown (run `claude --version` to verify)" : "✓ $claudeVersion (output mutation ${_postToolUseEnabled ? "supported" : "requires ${ClaudeCodeVersion.outputMutationMinimum}+"})"}');
    buf.writeln('Hook script (Bash, PreToolUse):  '
        '${File(hookScriptPath).existsSync() ? "✓ $hookScriptPath" : "✗ not installed"}');
    buf.writeln('Hook script (Task, PreToolUse):  '
        '${File(taskHookScriptPath).existsSync() ? "✓ $taskHookScriptPath" : "✗ not installed"}');
    buf.writeln('Hook script (Bash, PostToolUse): '
        '${File(bashPostHookScriptPath).existsSync() ? "✓ $bashPostHookScriptPath" : "✗ not installed"}');
    final settingsFile = File(settingsPath);
    if (!settingsFile.existsSync()) {
      buf.write('settings.json: ✗ $settingsPath not found');
      return buf.toString();
    }
    final settings = _loadSettings(settingsFile);
    for (final spec in _allSpecs(includePostToolUse: true)) {
      final entry = _findFlartEntry(settings, spec: spec);
      final label = '${spec.event}/${spec.matcher}';
      buf.writeln(entry == null
          ? 'settings.json ($label): ✗ no flart entry'
          : 'settings.json ($label): ✓ points to ${entry['command']}');
    }
    // Trim trailing newline for cleaner CLI output.
    final out = buf.toString();
    return out.endsWith('\n') ? out.substring(0, out.length - 1) : out;
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

    final actions = <String>[];
    // On install: write Pre+Task always, Post conditional on version.
    // On uninstall: purge ALL three regardless of version (stale entries
    // from a previously-upgraded flart install should not linger).
    final specs = install
        ? _allSpecs(includePostToolUse: _postToolUseEnabled)
        : _allSpecs(includePostToolUse: true);

    for (final spec in specs) {
      final eventList =
          (hooksRoot[spec.event] as List?)?.cast<dynamic>() ?? <dynamic>[];
      final mutable = eventList.toList();
      final existingIndex =
          mutable.indexWhere((e) => _isFlartEntryFor(e, spec: spec));
      if (install) {
        final newEntry = {
          'matcher': spec.matcher,
          'hooks': [
            {'type': 'command', 'command': spec.scriptPath},
          ],
        };
        if (existingIndex >= 0) {
          mutable[existingIndex] = newEntry;
          actions.add('updated ${spec.event}/${spec.matcher}');
        } else {
          mutable.add(newEntry);
          actions.add('installed ${spec.event}/${spec.matcher}');
        }
      } else {
        if (existingIndex >= 0) {
          mutable.removeAt(existingIndex);
          actions.add('removed ${spec.event}/${spec.matcher}');
        }
      }
      // Drop the event key entirely if removing the last entry leaves it
      // empty — keeps the settings.json tidy for users who only had flart.
      if (mutable.isEmpty) {
        hooksRoot.remove(spec.event);
      } else {
        hooksRoot[spec.event] = mutable;
      }
    }

    if (actions.isEmpty) {
      return 'settings.json: no flart entries; nothing to do.';
    }

    if (hooksRoot.isEmpty) {
      settings.remove('hooks');
    } else {
      settings['hooks'] = hooksRoot;
    }

    final pretty = const JsonEncoder.withIndent('  ').convert(settings);
    atomicWriteString(settingsPath, '$pretty\n');
    return 'settings.json: ${actions.join(', ')}.';
  }

  List<_MatcherSpec> _allSpecs({required bool includePostToolUse}) {
    final out = <_MatcherSpec>[
      _MatcherSpec(
          event: 'PreToolUse', matcher: 'Bash', scriptPath: hookScriptPath),
      _MatcherSpec(
          event: 'PreToolUse', matcher: 'Task', scriptPath: taskHookScriptPath),
    ];
    if (includePostToolUse) {
      out.add(_MatcherSpec(
          event: 'PostToolUse',
          matcher: 'Bash',
          scriptPath: bashPostHookScriptPath));
    }
    return out;
  }

  /// True when [e] is a flart entry for the given spec. Recognised by the
  /// matcher AND a `hooks[0].command` whose tail matches the spec's script
  /// filename — same convention the installer uses on write.
  bool _isFlartEntryFor(dynamic e, {required _MatcherSpec spec}) {
    if (e is! Map) return false;
    if (e['matcher'] != spec.matcher) return false;
    final hooks = e['hooks'];
    if (hooks is! List || hooks.isEmpty) return false;
    final h = hooks.first;
    if (h is! Map || h['command'] is! String) return false;
    final cmd = h['command'] as String;
    return cmd.endsWith('/${p.basename(spec.scriptPath)}');
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
    required _MatcherSpec spec,
  }) {
    final hooks = settings['hooks'];
    if (hooks is! Map) return null;
    final eventList = hooks[spec.event];
    if (eventList is! List) return null;
    for (final e in eventList) {
      if (_isFlartEntryFor(e, spec: spec)) {
        return Map<String, dynamic>.from((e as Map)['hooks'][0] as Map);
      }
    }
    return null;
  }
}

class _MatcherSpec {
  final String event;
  final String matcher;
  final String scriptPath;
  const _MatcherSpec({
    required this.event,
    required this.matcher,
    required this.scriptPath,
  });
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
  final Future<ClaudeCodeVersion?> Function() _detectVersion;

  HookChecker({
    Future<String?> Function(String exe)? whichExe,
    Future<ClaudeCodeVersion?> Function()? detectVersion,
  })  : _whichExe = whichExe ?? _defaultWhich,
        _detectVersion = detectVersion ?? detectClaudeVersion;

  Future<List<CheckResult>> diagnose({
    required String settingsPath,
    required String hookScriptPath,
    String? taskHookScriptPath,
    String? bashPostHookScriptPath,
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

    final version = await _detectVersion();
    final minVer = ClaudeCodeVersion.outputMutationMinimum;
    results.add(CheckResult(
      label: 'Claude Code',
      ok: version != null,
      detail: version == null
          ? 'version unknown (claude binary missing or unparseable)'
          : '$version (output mutation ${version >= minVer ? "supported" : "requires $minVer+"})',
      hint: version == null
          ? 'Install Claude Code or add it to \$PATH so flart can probe `claude --version`.'
          : (version < minVer
              ? 'Upgrade Claude Code to $minVer+ to enable PostToolUse / Bash '
                  'output mutation (other hooks still work on older versions).'
              : null),
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
      label: 'Hook script (Bash, PreToolUse)',
      ok: scriptInstalled,
      detail: scriptInstalled ? hookScriptPath : 'not installed',
      hint: scriptInstalled
          ? null
          : 'Run `flart init --global` to write it.',
    ));

    if (taskHookScriptPath != null) {
      final taskInstalled = File(taskHookScriptPath).existsSync();
      results.add(CheckResult(
        label: 'Hook script (Task, PreToolUse)',
        ok: taskInstalled,
        detail: taskInstalled ? taskHookScriptPath : 'not installed',
        hint: taskInstalled
            ? null
            : 'Run `flart init --global` to write it.',
      ));
    }

    if (bashPostHookScriptPath != null) {
      final installed = File(bashPostHookScriptPath).existsSync();
      // Only flag as an error when Claude Code supports it; otherwise the
      // installer correctly skipped writing this script.
      final shouldExist = version != null && version >= minVer;
      results.add(CheckResult(
        label: 'Hook script (Bash, PostToolUse)',
        ok: shouldExist ? installed : true,
        detail: installed
            ? bashPostHookScriptPath
            : (shouldExist
                ? 'not installed'
                : 'skipped (Claude Code < $minVer)'),
        hint: shouldExist && !installed
            ? 'Run `flart init --global` to write it.'
            : null,
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
