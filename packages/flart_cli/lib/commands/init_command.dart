import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_hooks/flart_hooks.dart';
import 'package:path/path.dart' as p;

/// `flart init` — Plan Section 7.3. Installs/inspects/removes the Claude
/// Code PreToolUse hook (global) and the CLAUDE.md routing block (project).
///
/// **Uninstall safety:** Removes only the integration surface (settings.json
/// entry + hook script + CLAUDE.md marker block). The savings DB at
/// `<dataDir>/savings.db` is intentionally untouched — users who want to
/// wipe history run `flart savings --reset`.
class InitCommand extends Command<int> {
  final FlartEnv? _envOverride;
  final IOSink? _stdoutOverride;
  final IOSink? _stderrOverride;
  final Stream<List<int>>? _stdinOverride;

  /// Test-only overrides for the install destination. Production resolves
  /// these from env via [resolveConfigHome] / [defaultClaudeSettingsPath].
  final String? _settingsPathOverride;
  final String? _hookScriptPathOverride;
  final String? _taskHookScriptPathOverride;
  final String? _claudeMdPathOverride;

  /// Injectable PATH probe (`flart init --check`). Defaults to running
  /// `which` via Process.run.
  final Future<String?> Function(String exe)? _whichExeOverride;

  InitCommand({
    FlartEnv? envOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
    Stream<List<int>>? stdinOverride,
    String? settingsPathOverride,
    String? hookScriptPathOverride,
    String? taskHookScriptPathOverride,
    String? claudeMdPathOverride,
    Future<String?> Function(String exe)? whichExeOverride,
  })  : _envOverride = envOverride,
        _stdoutOverride = stdoutOverride,
        _stderrOverride = stderrOverride,
        _stdinOverride = stdinOverride,
        _settingsPathOverride = settingsPathOverride,
        _hookScriptPathOverride = hookScriptPathOverride,
        _taskHookScriptPathOverride = taskHookScriptPathOverride,
        _claudeMdPathOverride = claudeMdPathOverride,
        _whichExeOverride = whichExeOverride {
    argParser
      ..addFlag('global',
          negatable: false,
          help:
              'Install only the global PreToolUse hook in ~/.claude/settings.json.')
      ..addFlag('project',
          negatable: false,
          help:
              'Install only the project routing block in <project>/CLAUDE.md.')
      ..addFlag('show',
          negatable: false,
          help: 'Show current installation status and exit.')
      ..addFlag('check',
          negatable: false,
          help:
              'Diagnose the install (PATH, jq, settings.json, CLAUDE.md). Exit 1 if any check fails.')
      ..addFlag('uninstall',
          negatable: false,
          help:
              'Remove flart hook + script + CLAUDE.md block. Savings DB is NOT touched.')
      ..addFlag('yes',
          negatable: false,
          abbr: 'y',
          help: 'Skip the confirmation prompt (CI use).');
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Install or inspect the Claude Code hook + project routing block.';

  @override
  String get invocation =>
      'flart init [--global | --project | --show | --check | --uninstall] [--yes]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final out = _stdoutOverride ?? stdout;
    final err = _stderrOverride ?? stderr;
    final env = _envOverride ?? FlartEnv.fromPlatform();

    final paths = _resolvePaths(env);

    final hookInstaller = HookInstaller(
      settingsPath: paths.settingsPath,
      hookScriptPath: paths.hookScriptPath,
      taskHookScriptPath: paths.taskHookScriptPath,
    );
    final projectInstaller = ProjectInstaller(claudeMdPath: paths.claudeMdPath);

    if (results['show'] as bool) {
      out.writeln(hookInstaller.describeState());
      final marker = projectInstaller.hasRoutingBlock()
          ? '✓ ${paths.claudeMdPath}'
          : '✗ ${paths.claudeMdPath} (no flart marker)';
      out.writeln('CLAUDE.md:     $marker');
      return 0;
    }

    if (results['check'] as bool) {
      final checker = HookChecker(whichExe: _whichExeOverride);
      final probes = await checker.diagnose(
        settingsPath: paths.settingsPath,
        hookScriptPath: paths.hookScriptPath,
        taskHookScriptPath: paths.taskHookScriptPath,
        projectClaudeMdPath: paths.claudeMdPath,
      );
      out.writeln(renderCheckTable(probes));
      final anyFailed = probes.any((r) => !r.ok);
      return anyFailed ? 1 : 0;
    }

    if (results['uninstall'] as bool) {
      return _runUninstall(
        out: out,
        err: err,
        hookInstaller: hookInstaller,
        projectInstaller: projectInstaller,
        scope: _resolveScope(results),
      );
    }

    return _runInstall(
      out: out,
      err: err,
      yes: results['yes'] as bool,
      hookInstaller: hookInstaller,
      projectInstaller: projectInstaller,
      scope: _resolveScope(results),
      paths: paths,
    );
  }

  Future<int> _runInstall({
    required IOSink out,
    required IOSink err,
    required bool yes,
    required HookInstaller hookInstaller,
    required ProjectInstaller projectInstaller,
    required _Scope scope,
    required _Paths paths,
  }) async {
    if (!yes) {
      final preview = _previewInstall(scope: scope, paths: paths);
      out.write(preview);
      out.write('Continue? [y/N] ');
      final ans = await _readLine(_stdinOverride ?? stdin);
      final normalized = ans.trim().toLowerCase();
      if (normalized != 'y' && normalized != 'yes') {
        out.writeln('Cancelled. No changes made.');
        return 0;
      }
    }

    if (scope.global) {
      for (final m in hookInstaller.installAll()) {
        out.writeln(m);
      }
    }
    if (scope.project) {
      out.writeln(projectInstaller.installRoutingBlock());
    }
    return 0;
  }

  Future<int> _runUninstall({
    required IOSink out,
    required IOSink err,
    required HookInstaller hookInstaller,
    required ProjectInstaller projectInstaller,
    required _Scope scope,
  }) async {
    if (scope.global) {
      for (final m in hookInstaller.uninstallAll()) {
        out.writeln(m);
      }
    }
    if (scope.project) {
      out.writeln(projectInstaller.removeRoutingBlock());
    }
    out.writeln(
        'Savings DB was not touched. Use `flart savings --reset` to clear history.');
    return 0;
  }

  _Scope _resolveScope(ArgResults results) {
    final wantsGlobal = results['global'] as bool;
    final wantsProject = results['project'] as bool;
    // No scope flags → both.
    if (!wantsGlobal && !wantsProject) {
      return const _Scope(global: true, project: true);
    }
    return _Scope(global: wantsGlobal, project: wantsProject);
  }

  String _previewInstall({required _Scope scope, required _Paths paths}) {
    final buf = StringBuffer(
      'flart init will perform the following:\n',
    );
    if (scope.global) {
      buf.writeln('  • Write hook scripts to:');
      buf.writeln('      ${paths.hookScriptPath}');
      buf.writeln('      ${paths.taskHookScriptPath}');
      buf.writeln(
          '  • Add PreToolUse matchers (Bash, Task) to ${paths.settingsPath}');
      buf.writeln(
          '    Bash matcher auto-allows commands the rewriter maps; Task '
          'matcher injects a flart usage hint into spawned sub-agents.');
      buf.writeln('    Other commands flow through Claude Code normally.');
    }
    if (scope.project) {
      buf.writeln(
          '  • Insert/update flart routing block in ${paths.claudeMdPath}');
      buf.writeln(
          '    (markers <!-- flart-routing-start -->/<!-- flart-routing-end --> '
          'so repeat runs replace the block).');
    }
    buf.writeln(
        '  • Savings DB at <dataDir>/savings.db is NOT touched.');
    return buf.toString();
  }

  _Paths _resolvePaths(FlartEnv env) {
    final settingsPath =
        _settingsPathOverride ?? defaultClaudeSettingsPath(env);
    final configHome = resolveConfigHome(env);
    final hookScriptPath =
        _hookScriptPathOverride ?? defaultHookScriptPath(configHome);
    final taskHookScriptPath =
        _taskHookScriptPathOverride ?? defaultTaskHookScriptPath(configHome);
    final claudeMdPath = _claudeMdPathOverride ??
        p.join(ProjectContext.detect().root, 'CLAUDE.md');
    return _Paths(
      settingsPath: settingsPath,
      hookScriptPath: hookScriptPath,
      taskHookScriptPath: taskHookScriptPath,
      claudeMdPath: claudeMdPath,
    );
  }

  Future<String> _readLine(Stream<List<int>> source) async {
    final bytes = <int>[];
    await for (final chunk in source) {
      for (final b in chunk) {
        if (b == 0x0A) return String.fromCharCodes(bytes);
        bytes.add(b);
      }
    }
    return String.fromCharCodes(bytes);
  }
}

class _Scope {
  final bool global;
  final bool project;
  const _Scope({required this.global, required this.project});
}

class _Paths {
  final String settingsPath;
  final String hookScriptPath;
  final String taskHookScriptPath;
  final String claudeMdPath;
  const _Paths({
    required this.settingsPath,
    required this.hookScriptPath,
    required this.taskHookScriptPath,
    required this.claudeMdPath,
  });
}
