import 'package:meta/meta.dart';

/// Captured result of running a sandbox script.
///
/// `stdout`/`stderr` are UTF-8 decoded with malformed-byte tolerance, capped
/// at `maxOutputBytes` (set on the executor call). `wasTruncated` flips to
/// true when either stream produced more bytes than the cap.
@immutable
class ExecResult {
  final String stdout;
  final String stderr;
  final int exitCode;

  /// True when the process was killed by the manual timeout. In that case
  /// [exitCode] is forced to 124 (POSIX timeout convention) regardless of the
  /// real exit code.
  final bool timedOut;

  /// True when at least one of stdout/stderr produced more bytes than the
  /// configured `maxOutputBytes` cap (excess bytes are silently dropped, the
  /// stream is still drained so the process doesn't block on a full pipe).
  final bool wasTruncated;

  const ExecResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    this.timedOut = false,
    this.wasTruncated = false,
  });

  @override
  String toString() =>
      'ExecResult(exitCode: $exitCode, timedOut: $timedOut, '
      'wasTruncated: $wasTruncated, stdoutBytes: ${stdout.length}, '
      'stderrBytes: ${stderr.length})';
}

/// Base class for all executor errors. Messages are actionable per Plan
/// Section 16.6 (tell the user how to fix it, not just what's wrong).
class ExecException implements Exception {
  final String message;
  const ExecException(this.message);
  @override
  String toString() => message;
}

/// Script source failed pre-execution validation (e.g. Dart mod-A import
/// rules in Plan Section 4.4).
class ImportValidationException extends ExecException {
  const ImportValidationException(super.message);
}

/// The requested runtime's executable was not found on PATH.
class RuntimeNotFoundException extends ExecException {
  const RuntimeNotFoundException(super.message);
}
