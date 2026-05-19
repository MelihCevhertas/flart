import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_hooks/flart_hooks.dart';
import 'package:path/path.dart' as p;

/// `flart bash-post-hook` — Claude Code PostToolUse / Bash hook entry point.
///
/// Pipeline:
///   1. Read JSON hook input on stdin.
///   2. Extract tool_input.command + tool_response.stdout/stderr/exit_code.
///   3. Tee raw combined output to `<dataDir>/tee/<epoch>_<slug>_bash.log`
///      (best-effort; failure does not abort the hook).
///   4. Run [BashPostFilter] to decide bypass vs mutate.
///   5. On mutate: record an `invocations` row (`module = bash_post`) with
///      raw/filtered byte and char counts so `flart savings` can credit
///      the filter.
///   6. Emit the JSON response — empty body on bypass (Claude Code keeps
///      raw output), `hookSpecificOutput.updatedToolOutput` otherwise.
///
/// Hidden subcommand: not intended for direct CLI use. Soft-fails on any
/// DB / FS error so the agent's tool result is never blocked.
class BashPostHookCommand extends Command<int> {
  final FlartEnv? _envOverride;
  final Stream<List<int>>? _stdinOverride;
  final IOSink? _stdoutOverride;
  final IOSink? _stderrOverride;
  final DateTime Function()? _nowOverride;

  BashPostHookCommand({
    FlartEnv? envOverride,
    Stream<List<int>>? stdinOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
    DateTime Function()? nowOverride,
  })  : _envOverride = envOverride,
        _stdinOverride = stdinOverride,
        _stdoutOverride = stdoutOverride,
        _stderrOverride = stderrOverride,
        _nowOverride = nowOverride;

  @override
  String get name => 'bash-post-hook';

  @override
  String get description =>
      'Internal: Claude Code PostToolUse/Bash hook entry point. Not for direct use.';

  @override
  bool get hidden => true;

  @override
  Future<int> run() async {
    final out = _stdoutOverride ?? stdout;
    final err = _stderrOverride ?? stderr;
    final env = _envOverride ?? FlartEnv.fromPlatform();
    final now = (_nowOverride ?? DateTime.now)().toUtc();

    final raw = await _readAll(_stdinOverride ?? stdin);
    final input = _decodeInput(raw);

    final command = _readNestedString(input, ['tool_input', 'command']) ?? '';
    final response = (input?['tool_response'] is Map)
        ? Map<String, Object?>.from(input!['tool_response'] as Map)
        : <String, Object?>{};
    final stdoutText = (response['stdout'] as String?) ?? '';
    final stderrText = (response['stderr'] as String?) ?? '';
    final exitCode = _readInt(response['exit_code'] ?? response['exitCode']);
    final cwd = _readString(input?['cwd']) ?? ProjectContext.detect().root;

    final dataDir = env.dataDir ?? _defaultDataDir(env);
    final teeDir = p.join(dataDir, 'tee');

    String? teePath;
    try {
      teePath = await _writeTee(
        teeDir: teeDir,
        epochSeconds: now.millisecondsSinceEpoch ~/ 1000,
        command: command,
        stdoutText: stdoutText,
        stderrText: stderrText,
      );
    } catch (e) {
      err.writeln('flart bash-post-hook: tee skipped ($e).');
      teePath = null;
    }

    final filter = BashPostFilter(teeDirectory: teeDir);
    final result = filter.filter(
      stdout: stdoutText,
      stderr: stderrText,
      exitCode: exitCode,
      command: command,
      teePath: teePath,
    );

    if (!result.bypass) {
      try {
        _recordInvocation(
          env: env,
          dataDir: dataDir,
          now: now,
          cwd: cwd,
          command: command,
          exitCode: exitCode,
          rawText: _rawTextFor(stdoutText, stderrText),
          result: result,
          teePath: teePath,
        );
      } catch (e) {
        err.writeln('flart bash-post-hook: skipped recording ($e).');
      }
    }

    if (result.bypass) {
      // Empty body keeps Claude Code's raw output. Exit 0 → no error to surface.
      return 0;
    }

    out.writeln(jsonEncode({
      'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'updatedToolOutput': result.updatedOutput,
        'additionalContext': result.additionalContext,
      },
    }));
    return 0;
  }

  // ---------- helpers ----------

  Map<String, Object?>? _decodeInput(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  String? _readNestedString(Map<String, Object?>? input, List<String> path) {
    Object? cursor = input;
    for (final key in path) {
      if (cursor is! Map) return null;
      cursor = cursor[key];
    }
    return _readString(cursor);
  }

  String? _readString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<String?> _writeTee({
    required String teeDir,
    required int epochSeconds,
    required String command,
    required String stdoutText,
    required String stderrText,
  }) async {
    final combined = stderrText.trim().isEmpty
        ? stdoutText
        : '$stdoutText\n---STDERR---\n$stderrText';
    if (combined.trim().isEmpty) return null;

    final dir = Directory(teeDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final slug = _slug(command);
    final filename = '${epochSeconds}_${slug}_bash.log';
    final filePath = p.join(teeDir, filename);
    await File(filePath).writeAsString(combined, flush: true);
    return filePath;
  }

  /// Filename-safe slug for the tee log. Mirrors flart_core/TeeManager's
  /// convention so paths are easy to spot. Capped at 32 chars.
  String _slug(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return 'bash';
    final firstToken = trimmed.split(RegExp(r'\s+')).first;
    final cleaned = firstToken
        .split('/')
        .last
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (cleaned.isEmpty) return 'bash';
    return cleaned.length <= 32 ? cleaned : cleaned.substring(0, 32);
  }

  void _recordInvocation({
    required FlartEnv env,
    required String dataDir,
    required DateTime now,
    required String cwd,
    required String command,
    required int exitCode,
    required String rawText,
    required BashPostFilterResult result,
    required String? teePath,
  }) {
    if (env.noSavings) return;
    final dbPath = p.join(dataDir, 'savings.db');
    final db = FlartDatabase.open(path: dbPath);
    try {
      final est = const TokenEstimator();
      final filteredText = result.updatedOutput ?? '';
      InvocationRepo(db).insert(InvocationRecord(
        timestamp: now,
        projectPath: cwd,
        module: 'bash_post',
        command: result.commandLabel,
        args: command.length > 240 ? '${command.substring(0, 237)}...' : command,
        rawBytes: result.rawBytes,
        filteredBytes: result.filteredBytes,
        rawChars: rawText.length,
        filteredChars: filteredText.length,
        estRawTokens: est.estimate(rawText),
        estFiltTokens: est.estimate(filteredText),
        durationMs: 0, // PostToolUse doesn't see the run time.
        exitCode: exitCode,
        teePath: teePath,
        metadata: const {'source': 'bash_post_hook'},
      ));
    } finally {
      db.dispose();
    }
  }

  String _rawTextFor(String stdoutText, String stderrText) {
    if (stderrText.trim().isEmpty) return stdoutText;
    if (stdoutText.trim().isEmpty) return stderrText;
    return '$stdoutText\n---STDERR---\n$stderrText';
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
    return utf8.decode(buf, allowMalformed: true);
  }
}
