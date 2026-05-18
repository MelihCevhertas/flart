import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'dart_wrapper.dart';
import 'exec_result.dart';
import 'runtime.dart';
import 'validators.dart';

/// Runs a script in one of the supported [Runtime]s and returns the captured
/// output. Plan Section 4.
class SandboxExecutor {
  final RuntimeDetector detector;

  SandboxExecutor({RuntimeDetector? detector})
      : detector = detector ?? RuntimeDetector();

  /// Runs [code] in [runtime] and returns the captured output.
  ///
  /// Pre-execution validation:
  /// - For [Runtime.dart], `package:` and relative imports are rejected
  ///   ([ImportValidationException]).
  /// - The runtime executable must resolve on PATH
  ///   ([RuntimeNotFoundException]).
  ///
  /// Capture:
  /// - stdout/stderr are buffered in a head + tail ring (Plan 4.5): the first
  ///   `headRatio * maxOutputBytes` and the last `(1 - headRatio) *
  ///   maxOutputBytes` are kept; the middle is dropped. When dropping occurs
  ///   [ExecResult.wasTruncated] is true and the assembled string contains a
  ///   marker line between head and tail showing the byte/line counts.
  /// - stdin is closed immediately so scripts reading from it don't hang.
  ///
  /// Timeout (Plan 4.3 v1.3):
  /// - When [timeout] elapses we SIGTERM the process; after a 2s grace period
  ///   we SIGKILL it. On timeout [ExecResult.timedOut] is true and
  ///   [ExecResult.exitCode] is forced to 124 (POSIX timeout convention).
  Future<ExecResult> execute({
    required Runtime runtime,
    required String code,
    Map<String, String>? environment,
    String? workingDirectory,
    int maxOutputBytes = 65536,
    double headRatio = 0.6,
    Duration timeout = const Duration(seconds: 60),
    Duration sigkillGrace = const Duration(seconds: 2),
  }) async {
    assert(maxOutputBytes > 0);
    assert(headRatio > 0 && headRatio < 1);

    if (runtime == Runtime.dart) {
      final err = validateDartImports(code);
      if (err != null) throw ImportValidationException(err);
    }

    final exe = await detector.detect(runtime);
    if (exe == null) {
      throw RuntimeNotFoundException(_runtimeNotFoundMessage(runtime));
    }

    final tmpDir = await Directory.systemTemp.createTemp('flart_exec_');
    Process? process;
    Timer? timeoutTimer;
    Timer? sigkillTimer;
    var killed = false;

    try {
      final scriptFile = File(
        p.join(tmpDir.path, 'script.${runtime.scriptExtension}'),
      );
      // For Dart, auto-wrap top-level code in `void main()` when no main
      // is declared (Plan Section 4.4 Auto-wrap, v1.4). Validation already
      // ran on the original `code`, so wrap never bypasses mod-A rules.
      final scriptSource =
          runtime == Runtime.dart ? wrapDartIfNeeded(code) : code;
      await scriptFile.writeAsString(scriptSource);

      process = await Process.start(
        exe,
        [scriptFile.path],
        environment: environment,
        workingDirectory: workingDirectory ?? Directory.current.path,
        runInShell: false,
      );

      // Close stdin immediately — scripts that `read` from stdin would
      // otherwise hang forever.
      await process.stdin.close();

      // Manual timeout: SIGTERM after [timeout], SIGKILL after [sigkillGrace]
      // if the process is still alive. `process.kill()` is a no-op on
      // already-dead processes. The sigkillTimer is declared at outer scope
      // so finally can cancel it (otherwise it would fire after we return).
      timeoutTimer = Timer(timeout, () {
        killed = true;
        process?.kill(ProcessSignal.sigterm);
        sigkillTimer = Timer(sigkillGrace, () {
          process?.kill(ProcessSignal.sigkill);
        });
      });

      final headCap = (maxOutputBytes * headRatio).floor();
      final tailCap = maxOutputBytes - headCap;
      final stdoutBuf = _CaptureBuffer(headCap: headCap, tailCap: tailCap);
      final stderrBuf = _CaptureBuffer(headCap: headCap, tailCap: tailCap);

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      final stdoutSub = process.stdout.listen(
        stdoutBuf.add,
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onError: (Object e, StackTrace s) {
          if (!stdoutDone.isCompleted) stdoutDone.completeError(e, s);
        },
      );
      final stderrSub = process.stderr.listen(
        stderrBuf.add,
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onError: (Object e, StackTrace s) {
          if (!stderrDone.isCompleted) stderrDone.completeError(e, s);
        },
      );

      // Process death is signalled by [exitCode] resolving. Stream `onDone`
      // can lag (sometimes by seconds) when an orphaned child still holds
      // the stdout/stderr pipe — classic Unix FD inheritance. After the
      // process exits, give streams a short grace period to flush, then
      // cancel the subscriptions so we don't wait on orphans.
      final exitCode = await process.exitCode;
      try {
        await Future.wait([stdoutDone.future, stderrDone.future])
            .timeout(const Duration(milliseconds: 200));
      } on TimeoutException {
        // Orphaned children still hold pipes; what we captured so far is
        // what the user gets.
      }
      await stdoutSub.cancel();
      await stderrSub.cancel();

      return ExecResult(
        stdout: stdoutBuf.assemble(),
        stderr: stderrBuf.assemble(),
        exitCode: killed ? 124 : exitCode,
        timedOut: killed,
        wasTruncated: stdoutBuf.overflowed || stderrBuf.overflowed,
      );
    } finally {
      timeoutTimer?.cancel();
      sigkillTimer?.cancel();
      try {
        await tmpDir.delete(recursive: true);
      } on FileSystemException {
        // Best-effort cleanup; ignore failures.
      }
    }
  }

  /// Convenience: reads a script from [filePath] and runs it via [execute].
  /// Throws [ExecException] when the file doesn't exist; other validation and
  /// capture semantics match [execute].
  Future<ExecResult> executeFile({
    required Runtime runtime,
    required String filePath,
    Map<String, String>? environment,
    String? workingDirectory,
    int maxOutputBytes = 65536,
    double headRatio = 0.6,
    Duration timeout = const Duration(seconds: 60),
    Duration sigkillGrace = const Duration(seconds: 2),
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ExecException(
        'flart exec: file not found: $filePath.\n'
        'Check the path or pass code as a positional argument instead.',
      );
    }
    final code = await file.readAsString();
    return execute(
      runtime: runtime,
      code: code,
      environment: environment,
      workingDirectory: workingDirectory,
      maxOutputBytes: maxOutputBytes,
      headRatio: headRatio,
      timeout: timeout,
      sigkillGrace: sigkillGrace,
    );
  }

  static String _runtimeNotFoundMessage(Runtime r) {
    switch (r) {
      case Runtime.dart:
        return "flart exec dart: 'dart' not found in PATH. "
            'Install Dart SDK: https://dart.dev/get-dart';
      case Runtime.bash:
        return "flart exec bash: 'bash' not found in PATH. "
            'Install bash via your system package manager '
            '(brew install bash on macOS, apt install bash on Debian/Ubuntu).';
      case Runtime.python:
        return "flart exec python: 'python' not found in PATH. "
            'Tried: python3, python. Install Python 3 or use bash/node.';
      case Runtime.node:
        return "flart exec node: 'node' not found in PATH. "
            'Install Node.js: https://nodejs.org or via a version manager '
            '(nvm, fnm).';
    }
  }
}

/// Head + tail ring buffer. Stores the first [headCap] bytes verbatim, then
/// the last [tailCap] bytes via a sliding window. Bytes dropped from the
/// middle are counted so the assembled string can include an accurate marker.
class _CaptureBuffer {
  final int headCap;
  final int tailCap;
  final List<int> _head = [];
  final Queue<int> _tail = Queue<int>();
  int _droppedFromTail = 0;
  int _droppedNewlines = 0;

  _CaptureBuffer({required this.headCap, required this.tailCap});

  void add(List<int> chunk) {
    for (final b in chunk) {
      if (_head.length < headCap) {
        _head.add(b);
      } else {
        _tail.add(b);
        if (_tail.length > tailCap) {
          final popped = _tail.removeFirst();
          if (popped == 0x0A) _droppedNewlines++;
          _droppedFromTail++;
        }
      }
    }
  }

  bool get overflowed => _droppedFromTail > 0;

  /// UTF-8 decoded string. When overflowed, inserts a marker line between
  /// head and tail. `allowMalformed` covers the rare case where head or tail
  /// boundaries split a multi-byte code point.
  String assemble() {
    final headStr = utf8.decode(_head, allowMalformed: true);
    final tailStr = utf8.decode(_tail.toList(), allowMalformed: true);
    if (!overflowed) return headStr + tailStr;
    final marker =
        '\n... [$_droppedFromTail bytes / $_droppedNewlines lines truncated '
        '— kept first ${_head.length} + last ${_tail.length}] ...\n';
    return '$headStr$marker$tailStr';
  }
}
