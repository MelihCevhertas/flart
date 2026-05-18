import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

/// Orchestrates a [CommandFilter]: spawns the native command, captures
/// stdout/stderr, delegates pure transformation to the filter, writes the
/// compact output, persists the invocation, and runs tee on failure.
///
/// Lives in `flart_cli` (not `flart_filters`) because process spawning, tee,
/// and savings tracking are CLI concerns. See Plan Section 5.3.
class FilterRunner {
  final CommandFilter filter;
  final InvocationTracker tracker;
  final TeeManager? tee;
  final IOSink _stdoutSink;
  final IOSink _stderrSink;

  FilterRunner({
    required this.filter,
    required this.tracker,
    this.tee,
    IOSink? stdoutSink,
    IOSink? stderrSink,
  })  : _stdoutSink = stdoutSink ?? stdout,
        _stderrSink = stderrSink ?? stderr;

  /// Runs the filter pipeline. Returns the underlying tool's exit code
  /// (passthrough per Plan Section 8.3); `filter.filter()` cannot change it.
  Future<int> run(List<String> userArgs) async {
    final stopwatch = Stopwatch()..start();
    final nativeCmd = filter.baseNativeCommand(userArgs);
    if (nativeCmd.isEmpty) {
      throw StateError(
        'Filter "${filter.name}" returned an empty baseNativeCommand list.',
      );
    }
    final fullArgs = [...nativeCmd.skip(1), ...userArgs];

    final Process process;
    try {
      process = await Process.start(
        nativeCmd.first,
        fullArgs,
        environment: filter.environment(userArgs),
        runInShell: false,
      );
    } on ProcessException catch (e) {
      stopwatch.stop();
      _stderrSink.writeln(
        'flart ${filter.flartCommand}: failed to start `${nativeCmd.first}` — ${e.message}',
      );
      return 127;
    }
    // No data piped to the underlying tool's stdin.
    await process.stdin.close();

    final rawStdoutFuture = process.stdout.transform(utf8.decoder).join();
    final rawStderrFuture = process.stderr.transform(utf8.decoder).join();

    final exitCode = await process.exitCode;
    final rawStdout = await rawStdoutFuture;
    final rawStderr = await rawStderrFuture;
    stopwatch.stop();

    final result = filter.filter(
      stdout: rawStdout,
      stderr: rawStderr,
      exitCode: exitCode,
      userArgs: userArgs,
    );

    // Tee raw output to disk before transforming. The separator makes the
    // resulting file human-debuggable; `flart` only writes it, never reads.
    String? teePath;
    if (tee != null && tee!.shouldTee(exitCode)) {
      teePath = await tee!.write(
        filter.name,
        '$rawStdout\n---STDERR---\n$rawStderr',
      );
    }

    // Normalize trailing newline up-front so the DB's `filtered_bytes` matches
    // exactly what the agent sees on stdout. Single source of truth — savings
    // reports measure agent context cost, which includes the newline.
    final rawCombined = '$rawStdout$rawStderr';
    final candidate =
        result.output.endsWith('\n') ? result.output : '${result.output}\n';
    // Anti-bloat: when the underlying command produced substantive output,
    // a filter that can't compress it should get out of the way — the agent
    // pays at most what the un-wrapped command would have cost. When raw is
    // empty/whitespace (e.g. `dart analyze` clean run prints nothing), the
    // filter's user-friendly "No issues." message is preferred even though
    // it's nominally larger.
    final rawHasSubstance = rawCombined.trim().isNotEmpty;
    final filteredBody =
        rawHasSubstance && candidate.length >= rawCombined.length
            ? (rawCombined.endsWith('\n') ? rawCombined : '$rawCombined\n')
            : candidate;

    // Tee hint is part of the *agent-visible* output, so it counts toward the
    // DB's filtered_bytes too. (The hint never beats the anti-bloat check
    // — it's appended after, since "where to find the rest" is value-add.)
    final filteredOutput =
        teePath != null ? '$filteredBody[full output: $teePath]\n' : filteredBody;

    await tracker.record(
      module: 'filter',
      command: filter.flartCommand,
      args: userArgs.join(' '),
      rawText: '$rawStdout$rawStderr',
      filteredText: filteredOutput,
      durationMs: stopwatch.elapsedMilliseconds,
      exitCode: exitCode,
      wasTruncated: result.wasTruncated,
      teePath: teePath,
      metadata: result.metadata,
    );

    _stdoutSink.write(filteredOutput);

    return exitCode;
  }
}
