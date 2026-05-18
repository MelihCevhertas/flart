import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_executor/flart_executor.dart';
import 'package:path/path.dart' as p;

/// `flart exec` — run a script in a sandboxed runtime and record the
/// invocation to the savings DB.
///
/// Three input modes (mutually exclusive):
/// - `flart exec <runtime> '<code>'`          — code as positional arg
/// - `flart exec <runtime> --file <path>`     — code from file on disk
/// - `flart exec <runtime> --stdin`           — code from stdin pipe
class ExecCommand extends Command<int> {
  final FlartEnv? _envOverride;
  final Stream<List<int>>? _stdinOverride;
  final IOSink? _stdoutOverride;
  final IOSink? _stderrOverride;

  ExecCommand({
    FlartEnv? envOverride,
    Stream<List<int>>? stdinOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
  })  : _envOverride = envOverride,
        _stdinOverride = stdinOverride,
        _stdoutOverride = stdoutOverride,
        _stderrOverride = stderrOverride {
    argParser
      ..addOption(
        'timeout',
        help: 'Process timeout in seconds.',
        defaultsTo: '60',
      )
      ..addOption(
        'max-output',
        help: 'Max bytes to keep per stream (head + tail buffer). '
            'Suffix "k" or "m" allowed (e.g. 32k, 1m).',
        defaultsTo: '65536',
      )
      ..addOption(
        'file',
        help: 'Read script source from the given path.',
      )
      ..addFlag(
        'stdin',
        negatable: false,
        help: 'Read script source from stdin.',
      );
  }

  @override
  String get name => 'exec';

  @override
  String get description =>
      'Run a script in a sandboxed runtime (dart, bash, python, node).';

  @override
  String get invocation =>
      'flart exec [flags] <runtime> [<code> | --file <path> | --stdin]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final rest = results.rest;

    final out = _stdoutOverride ?? stdout;
    final err = _stderrOverride ?? stderr;

    if (rest.isEmpty) {
      usageException('Missing required <runtime> argument.');
    }

    final Runtime runtime;
    try {
      runtime = Runtime.resolve(rest[0]);
    } on ArgumentError catch (e) {
      usageException(e.message.toString());
    }

    final hasFile = results['file'] != null;
    final hasStdin = results['stdin'] as bool;
    final hasInlineCode = rest.length >= 2;
    final modesProvided =
        [hasFile, hasStdin, hasInlineCode].where((x) => x).length;
    if (modesProvided == 0) {
      usageException(
        'Provide code as the second positional argument, --file <path>, or --stdin.',
      );
    }
    if (modesProvided > 1) {
      usageException(
        'Choose exactly one input mode: positional code, --file, or --stdin.',
      );
    }

    final String code;
    if (hasInlineCode) {
      code = rest.skip(1).join(' ');
    } else if (hasFile) {
      final path = results['file'] as String;
      final file = File(path);
      if (!file.existsSync()) {
        err.writeln('flart exec: file not found: $path');
        return 101;
      }
      code = await file.readAsString();
    } else {
      code = await _readStdin();
    }

    final timeoutSecs = int.tryParse(results['timeout'] as String);
    if (timeoutSecs == null || timeoutSecs <= 0) {
      usageException(
        '--timeout must be a positive integer (seconds); got '
        '"${results['timeout']}".',
      );
    }
    final int maxOutput;
    try {
      maxOutput = parseSize(results['max-output'] as String);
    } on FormatException catch (e) {
      usageException('--max-output: ${e.message}');
    }

    final env = _envOverride ?? FlartEnv.fromPlatform();
    final config = Config.defaults();
    final project = ProjectContext.detect();
    final dbPath = _resolveDbPath(env);
    Directory(p.dirname(dbPath)).createSync(recursive: true);

    final db = FlartDatabase.open(path: dbPath);
    try {
      final repo = InvocationRepo(db);
      final estimator = TokenEstimator.fromConfig(config);
      final tracker = InvocationTracker(
        repo: repo,
        estimator: estimator,
        project: project,
        env: env,
      );
      final executor = SandboxExecutor();

      final sw = Stopwatch()..start();
      final ExecResult execResult;
      try {
        execResult = await executor.execute(
          runtime: runtime,
          code: code,
          timeout: Duration(seconds: timeoutSecs),
          maxOutputBytes: maxOutput,
          headRatio: config.executor.headRatio,
        );
      } on ExecException catch (e) {
        sw.stop();
        err.writeln(e.message);
        // RuntimeNotFoundException uses Plan exit 127; everything else 101.
        return e is RuntimeNotFoundException ? 127 : 101;
      }
      sw.stop();

      out.write(execResult.stdout);
      if (execResult.stderr.isNotEmpty) err.write(execResult.stderr);
      if (execResult.timedOut) {
        err.writeln('[flart exec: timed out after ${timeoutSecs}s]');
      }

      // Executor doesn't have a raw/filtered distinction — both equal the
      // captured (possibly truncated) output. The savings ratio for executor
      // is meaningful by *invocation count*, not byte-reduction (the value
      // is in NOT reading source files to compute the same answer).
      final captured = execResult.stdout + execResult.stderr;
      await tracker.record(
        module: 'executor',
        command: 'exec',
        args: rest[0],
        rawText: captured,
        filteredText: captured,
        durationMs: sw.elapsedMilliseconds,
        exitCode: execResult.exitCode,
        wasTruncated: execResult.wasTruncated,
        metadata: {
          'runtime': runtime.name,
          'timed_out': execResult.timedOut,
        },
      );

      return execResult.exitCode;
    } finally {
      db.dispose();
    }
  }

  Future<String> _readStdin() async {
    final source = _stdinOverride ?? stdin;
    final bytes = <int>[];
    await for (final chunk in source) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _resolveDbPath(FlartEnv env) {
    final dataDir = env.dataDir ?? _defaultDataDir(env);
    return p.join(dataDir, 'savings.db');
  }

  static String _defaultDataDir(FlartEnv env) {
    final home = env.home;
    if (home == null) return Directory.systemTemp.path;
    return p.join(home, '.local', 'share', 'flart');
  }
}

/// Parses a size string like `65536`, `32k`, `1m` into bytes.
///
/// `k` = 1024, `m` = 1024 * 1024. Case-insensitive. Throws [FormatException]
/// on invalid input.
int parseSize(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) {
    throw const FormatException('size cannot be empty');
  }
  int multiplier = 1;
  String numericPart = s;
  if (s.endsWith('k')) {
    multiplier = 1024;
    numericPart = s.substring(0, s.length - 1);
  } else if (s.endsWith('m')) {
    multiplier = 1024 * 1024;
    numericPart = s.substring(0, s.length - 1);
  }
  final n = int.tryParse(numericPart);
  if (n == null || n <= 0) {
    throw FormatException(
      'invalid size "$raw" — expected integer with optional k/m suffix',
    );
  }
  return n * multiplier;
}
