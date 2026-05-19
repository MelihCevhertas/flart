import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_hooks/flart_hooks.dart';
import 'package:path/path.dart' as p;

/// `flart task-hook` — runs as a Claude Code PreToolUse / Task hook. Reads
/// the hook JSON on stdin, records the sub-agent activation in the savings
/// DB, and prints the JSON response carrying the flart routing
/// [taskAdditionalContext] for the spawned sub-agent.
///
/// Hook contract:
/// - Never crashes Claude Code: any DB or parsing failure degrades to "no
///   recording, still emit context" (the user's sub-agent still gets the
///   hint). The exception is fatal stdin read errors, which exit non-zero
///   so Claude Code can surface them.
class TaskHookCommand extends Command<int> {
  final FlartEnv? _envOverride;
  final Stream<List<int>>? _stdinOverride;
  final IOSink? _stdoutOverride;
  final IOSink? _stderrOverride;

  TaskHookCommand({
    FlartEnv? envOverride,
    Stream<List<int>>? stdinOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
  })  : _envOverride = envOverride,
        _stdinOverride = stdinOverride,
        _stdoutOverride = stdoutOverride,
        _stderrOverride = stderrOverride;

  @override
  String get name => 'task-hook';

  @override
  String get description =>
      'Internal: Claude Code PreToolUse/Task hook entry point. Not for direct use.';

  @override
  bool get hidden => true;

  @override
  Future<int> run() async {
    final out = _stdoutOverride ?? stdout;
    final err = _stderrOverride ?? stderr;
    final env = _envOverride ?? FlartEnv.fromPlatform();

    final raw = await _readAll(_stdinOverride ?? stdin);
    Map<String, Object?>? input;
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          input = Map<String, Object?>.from(decoded);
        }
      } on FormatException {
        // Bad JSON on stdin — record nothing, still emit context.
      }
    }

    // Recording is best-effort. A missing/locked DB or a permission error
    // must not block the sub-agent spawn.
    try {
      _recordActivation(env: env, input: input);
    } catch (e) {
      err.writeln('flart task-hook: skipped recording ($e).');
    }

    final response = {
      'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'additionalContext': taskAdditionalContext,
      },
    };
    out.writeln(jsonEncode(response));
    return 0;
  }

  void _recordActivation({
    required FlartEnv env,
    Map<String, Object?>? input,
  }) {
    if (env.noSavings) return;
    final dataDir = env.dataDir ?? _defaultDataDir(env);
    final dbPath = p.join(dataDir, 'savings.db');
    // Open will create the DB on first call; migrations run automatically.
    final db = FlartDatabase.open(path: dbPath);
    try {
      final projectPath =
          _stringField(input, 'cwd') ?? ProjectContext.detect().root;
      final sessionId = _stringField(input, 'session_id');
      SubagentActivationRepo(db).insert(
        SubagentActivation(
          timestamp: DateTime.now().toUtc(),
          projectPath: projectPath,
          parentSessionId: sessionId,
        ),
      );
    } finally {
      db.dispose();
    }
  }

  String? _stringField(Map<String, Object?>? input, String key) {
    if (input == null) return null;
    final v = input[key];
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  static String _defaultDataDir(FlartEnv env) {
    final home = env.home;
    if (home == null) return Directory.systemTemp.path;
    return p.join(home, '.local', 'share', 'flart');
  }

  Future<String> _readAll(Stream<List<int>> source) async {
    final buf = <int>[];
    await for (final chunk in source) {
      buf.addAll(chunk);
    }
    return utf8.decode(buf);
  }
}
