import 'dart:io';

import '../config/config.dart';

/// Level-based logger that writes to stderr (always) and an optional file
/// (when `log.file` is set). See Plan Section 3.7.
///
/// Format on stderr: `[HH:MM:SS] LEVEL message`
/// Format in file:   `2026-05-17T14:30:18+0300 LEVEL message`
class Logger {
  final LogLevel level;
  final IOSink? fileSink;
  final IOSink _stderrSink;
  final DateTime Function() _now;

  Logger({
    required this.level,
    this.fileSink,
    IOSink? stderrSink,
    DateTime Function()? now,
  })  : _stderrSink = stderrSink ?? stderr,
        _now = now ?? DateTime.now;

  /// Builds a Logger from [LogConfig]. Opens the configured file in append
  /// mode (creates parent dirs if missing). Caller owns lifecycle and should
  /// call [close] before exit.
  factory Logger.fromConfig(
    LogConfig config, {
    IOSink? stderrSink,
    DateTime Function()? now,
  }) {
    IOSink? sink;
    if (config.file != null) {
      final file = File(config.file!);
      final parent = file.parent;
      if (!parent.existsSync()) parent.createSync(recursive: true);
      sink = file.openWrite(mode: FileMode.append);
    }
    return Logger(
      level: config.level,
      fileSink: sink,
      stderrSink: stderrSink,
      now: now,
    );
  }

  void debug(String msg) => _log(LogLevel.debug, msg);
  void info(String msg) => _log(LogLevel.info, msg);
  void warn(String msg) => _log(LogLevel.warn, msg);

  void error(String msg, [Object? error, StackTrace? stack]) {
    _log(LogLevel.error, msg);
    if (error != null) _log(LogLevel.error, '  $error');
    if (stack != null) _log(LogLevel.error, stack.toString());
  }

  void _log(LogLevel msgLevel, String message) {
    if (msgLevel.index < level.index) return;
    final now = _now();
    _stderrSink.writeln(_formatStderr(now, msgLevel, message));
    fileSink?.writeln(_formatFile(now, msgLevel, message));
  }

  static String _formatStderr(DateTime now, LogLevel level, String message) {
    final hh = _pad2(now.hour);
    final mm = _pad2(now.minute);
    final ss = _pad2(now.second);
    final levelStr = level.name.toUpperCase().padRight(5);
    return '[$hh:$mm:$ss] $levelStr $message';
  }

  static String _formatFile(DateTime now, LogLevel level, String message) {
    final isoBase = now.toIso8601String();
    final upTo = isoBase.length >= 19 ? isoBase.substring(0, 19) : isoBase;
    final tz = now.isUtc ? 'Z' : _tzOffset(now.timeZoneOffset);
    final levelStr = level.name.toUpperCase().padRight(5);
    return '$upTo$tz $levelStr $message';
  }

  static String _tzOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final h = _pad2(totalMinutes ~/ 60);
    final m = _pad2(totalMinutes % 60);
    return '$sign$h$m';
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// Closes the file sink (if any). Idempotent.
  Future<void> close() async {
    await fileSink?.flush();
    await fileSink?.close();
  }
}
