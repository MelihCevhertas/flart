import 'dart:convert';

import 'package:flart_core/flart_core.dart';
import 'package:meta/meta.dart';

/// Outcome of [BashPostFilter.filter]. [bypass] true means the hook should
/// return a no-op response and leave Claude Code's view of the output
/// untouched. Otherwise [updatedOutput] is what the agent sees;
/// [additionalContext] becomes a short system-reminder, and the byte/char
/// counts feed the savings DB.
@immutable
class BashPostFilterResult {
  final bool bypass;

  /// Human-readable code for *why* the filter bypassed. Surfaced in tests
  /// so we can assert against branches without overspecifying output text.
  /// One of: `flart-prefix`, `tee-read`, `explicit-env`, `small-output`,
  /// `empty-output`, `bloat-fallback`, `none` (when [bypass] is false).
  final String bypassReason;

  /// The text Claude Code will swap into the agent's tool result via
  /// `hookSpecificOutput.updatedToolOutput`. `null` when [bypass] is true —
  /// there's nothing to swap in.
  final String? updatedOutput;

  /// Short hint added as a system reminder so the agent knows the output
  /// was filtered and what the escape hatch is. `null` when [bypass] is true.
  final String? additionalContext;

  /// Single-token grouping label for the savings DB `command` column:
  /// the first whitespace token, with special cases for `python -c` /
  /// `dart -c` / shell builtins. Always populated, even on bypass — the
  /// CLI uses it for logging and structured output.
  final String commandLabel;

  /// Raw bytes of `stdout + stderr` *before* filtering. Recorded for the
  /// savings DB; equal to filteredBytes on bypass.
  final int rawBytes;

  /// Bytes the agent actually sees after filtering. On bypass this equals
  /// [rawBytes]; the CLI uses the gap to compute savings.
  final int filteredBytes;

  /// Raw line count (pre-filter), used in user-facing messages
  /// ("of N lines"). Counts both stdout and stderr lines.
  final int rawLines;

  const BashPostFilterResult({
    required this.bypass,
    required this.bypassReason,
    this.updatedOutput,
    this.additionalContext,
    required this.commandLabel,
    required this.rawBytes,
    required this.filteredBytes,
    required this.rawLines,
  });
}

/// Pure-function PostToolUse / Bash output filter. No I/O — the CLI command
/// owns stdin, tee writes, and DB inserts; this class only decides what the
/// agent sees and how to label the invocation.
///
/// Decision tree (in order):
/// 1. Empty output → bypass (`empty-output`). Nothing to filter.
/// 2. Command starts with `flart ` (after optional `cd … && ` prefix) →
///    bypass (`flart-prefix`). flart subcommands ship their own compact
///    output; double-filtering would inflate the response.
/// 3. Command contains `FLART_FULL_OUTPUT=1` → bypass (`explicit-env`).
///    Explicit escape; the agent (or user) opted in to the raw view.
/// 4. Command's first token is `cat | head | tail | less | more | wc | grep`
///    AND any positional arg points under the tee directory → bypass
///    (`tee-read`). Recovery path mustn't loop back through the filter.
/// 5. Exit code zero AND line count ≤ [BashFilterThresholds.passthroughLines]
///    → bypass (`small-output`). Nothing to gain by mutating.
/// 6. Otherwise filter per the size/error tier.
class BashPostFilter {
  final BashFilterThresholds thresholds;

  /// Absolute path of the tee dir, used by the `tee-read` bypass rule.
  /// Pass the resolved `<dataDir>/tee` — `null` disables the rule.
  final String? teeDirectory;

  const BashPostFilter({
    this.thresholds = BashFilterThresholds.defaults,
    this.teeDirectory,
  });

  /// Top-level entry point. [teePath] is the path the CLI just wrote the
  /// raw output to (or `null` when tee was disabled / output too small).
  /// It's only referenced in [BashPostFilterResult.additionalContext].
  BashPostFilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required String command,
    String? teePath,
  }) {
    final combined = _combine(stdout, stderr);
    final rawBytes = utf8.encode(combined).length;
    final lines = combined.isEmpty ? const <String>[] : combined.split('\n');
    // Trailing newline introduces a phantom empty line; trim it out of the count.
    final rawLines =
        (combined.endsWith('\n') && lines.isNotEmpty) ? lines.length - 1 : lines.length;
    final label = _commandLabel(command);

    BashPostFilterResult passthrough(String reason) => BashPostFilterResult(
          bypass: true,
          bypassReason: reason,
          commandLabel: label,
          rawBytes: rawBytes,
          filteredBytes: rawBytes,
          rawLines: rawLines,
        );

    if (combined.trim().isEmpty) {
      return passthrough('empty-output');
    }
    if (_isFlartPrefixed(command)) {
      return passthrough('flart-prefix');
    }
    if (command.contains('FLART_FULL_OUTPUT=1')) {
      return passthrough('explicit-env');
    }
    if (_isTeeReadCommand(command)) {
      return passthrough('tee-read');
    }
    if (exitCode == 0 && rawLines <= thresholds.passthroughLines) {
      return passthrough('small-output');
    }

    // From here, we mutate. Choose the strategy.
    final String updatedOutput;
    if (exitCode != 0) {
      updatedOutput = _renderErrorOutput(
        stdout: stdout,
        stderr: stderr,
        exitCode: exitCode,
        teePath: teePath,
      );
    } else if (rawLines <= thresholds.largeLines) {
      updatedOutput = _renderMedium(
        combined: combined,
        rawLines: rawLines,
        teePath: teePath,
      );
    } else {
      updatedOutput = _renderLarge(
        combined: combined,
        rawLines: rawLines,
        teePath: teePath,
      );
    }

    final filteredBytes = utf8.encode(updatedOutput).length;
    // Anti-bloat fallback (mirrors flart_filters/FilterRunner): for short
    // medium outputs the intro + footer metadata can exceed the body savings.
    // Don't make the agent pay more than the raw command would have.
    if (filteredBytes >= rawBytes) {
      return passthrough('bloat-fallback');
    }
    return BashPostFilterResult(
      bypass: false,
      bypassReason: 'none',
      updatedOutput: updatedOutput,
      additionalContext: _additionalContext(teePath: teePath),
      commandLabel: label,
      rawBytes: rawBytes,
      filteredBytes: filteredBytes,
      rawLines: rawLines,
    );
  }

  // ---------- bypass detection ----------

  static final RegExp _leadingCd =
      RegExp(r'^\s*cd\s+[^&;|]+?\s*&&\s*(.+)$');

  static const Set<String> _shellBuiltins = {
    'cd', 'export', 'source', 'alias', 'set', 'unset', 'eval', '.'
  };

  static const Set<String> _teeReaderCommands = {
    'cat', 'head', 'tail', 'less', 'more', 'wc', 'grep'
  };

  bool _isFlartPrefixed(String command) {
    final stripped = _stripLeadingCd(command).trimLeft();
    return stripped == 'flart' || stripped.startsWith('flart ');
  }

  bool _isTeeReadCommand(String command) {
    if (teeDirectory == null || teeDirectory!.isEmpty) return false;
    final stripped = _stripLeadingCd(command).trim();
    if (stripped.isEmpty) return false;
    final parts = stripped.split(RegExp(r'\s+'));
    if (parts.isEmpty) return false;
    if (!_teeReaderCommands.contains(parts.first)) return false;
    // Any positional arg referencing the tee dir is enough.
    for (final arg in parts.skip(1)) {
      if (arg.contains(teeDirectory!)) return true;
    }
    return false;
  }

  String _stripLeadingCd(String command) {
    final m = _leadingCd.firstMatch(command);
    return m == null ? command : m.group(1)!;
  }

  // ---------- command label extraction ----------

  /// Grouping key for the savings DB. Strips a leading `cd … && `, then:
  /// - shell builtin → `shell`
  /// - `python|python3 -c …` → `python3 -c`
  /// - `dart -c …`           → `dart -c`
  /// - otherwise               → first token (basename if it looks like a path)
  String _commandLabel(String command) {
    final stripped = _stripLeadingCd(command).trim();
    if (stripped.isEmpty) return 'unknown';
    final tokens = stripped.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return 'unknown';
    final first = tokens.first;
    if (_shellBuiltins.contains(first)) return 'shell';
    if ((first == 'python' || first == 'python3') &&
        tokens.length >= 2 &&
        tokens[1] == '-c') {
      return '$first -c';
    }
    if (first == 'dart' && tokens.length >= 2 && tokens[1] == '-c') {
      return 'dart -c';
    }
    // Path-shaped (`./script.sh`, `/usr/bin/foo`) → keep the basename so
    // grouping doesn't fragment per absolute path.
    if (first.contains('/')) {
      final basename = first.split('/').last;
      return basename.isEmpty ? first : basename;
    }
    return first;
  }

  // ---------- rendering ----------

  String _combine(String stdout, String stderr) {
    if (stderr.trim().isEmpty) return stdout;
    if (stdout.trim().isEmpty) return stderr;
    return '$stdout\n---STDERR---\n$stderr';
  }

  String _renderMedium({
    required String combined,
    required int rawLines,
    required String? teePath,
  }) {
    final lines = combined.split('\n');
    final head = lines.take(thresholds.mediumHeadLines).join('\n');
    final tailStart = rawLines - thresholds.mediumTailLines;
    final tail = tailStart > thresholds.mediumHeadLines
        ? lines
            .skip(tailStart)
            .take(thresholds.mediumTailLines)
            .join('\n')
        : '';
    final buf = StringBuffer()
      ..writeln(
          'Output filtered by flart: showing first ${thresholds.mediumHeadLines} '
          '+ last ${thresholds.mediumTailLines} of $rawLines lines.')
      ..writeln(head);
    if (tail.isNotEmpty) {
      buf
        ..writeln('… [${rawLines - thresholds.mediumHeadLines - thresholds.mediumTailLines}'
            ' lines elided] …')
        ..writeln(tail);
    }
    _appendRecoveryFooter(buf, teePath);
    return buf.toString();
  }

  String _renderLarge({
    required String combined,
    required int rawLines,
    required String? teePath,
  }) {
    final lines = combined.split('\n');
    final head = lines.take(thresholds.largeHeadLines).join('\n');
    final tailStart = rawLines - thresholds.largeTailLines;
    final effectiveTailStart =
        tailStart < thresholds.largeHeadLines ? thresholds.largeHeadLines : tailStart;
    final tail = lines.skip(effectiveTailStart).take(thresholds.largeTailLines).join('\n');

    // Error grep scans only the *elided* body (between head and tail) — head
    // and tail already render verbatim, so duplicating their matches would
    // inflate the output for warning-heavy logs and trip the anti-bloat
    // fallback. The match adds value precisely when an interesting line
    // sits in the middle and would otherwise be dropped.
    final errorRegex = RegExp(
        r'(error|warning|fail|fatal|exception|traceback|cannot)',
        caseSensitive: false);
    final elidedSlice = lines
        .skip(thresholds.largeHeadLines)
        .take(effectiveTailStart - thresholds.largeHeadLines);
    final errors =
        elidedSlice.where((l) => errorRegex.hasMatch(l)).take(thresholds.largeErrorLines).toList();

    final buf = StringBuffer()
      ..writeln(
          'Output filtered by flart: showing first ${thresholds.largeHeadLines} '
          '+ last ${thresholds.largeTailLines} of $rawLines lines.')
      ..writeln(head)
      ..writeln('… [body elided] …')
      ..writeln(tail);
    if (errors.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('Error-flavoured lines from the elided body (${errors.length}):')
        ..writeln(errors.join('\n'));
    }
    _appendRecoveryFooter(buf, teePath);
    return buf.toString();
  }

  String _renderErrorOutput({
    required String stdout,
    required String stderr,
    required int exitCode,
    required String? teePath,
  }) {
    final stderrBytes = utf8.encode(stderr);
    final cap = thresholds.errorStderrCapBytes;
    final stderrShown = stderrBytes.length <= cap
        ? stderr
        : '${utf8.decode(stderrBytes.sublist(0, cap), allowMalformed: true)}'
            '\n… [stderr truncated at $cap B; full log in tee] …';
    final stderrSizeKb = (stderrBytes.length / 1024).toStringAsFixed(1);

    final stdoutLines = stdout.isEmpty ? const <String>[] : stdout.split('\n');
    // Drop the phantom empty last entry that comes from a trailing newline.
    final stdoutLineCount = (stdout.endsWith('\n') && stdoutLines.isNotEmpty)
        ? stdoutLines.length - 1
        : stdoutLines.length;
    final tailN = thresholds.errorStdoutTailLines;
    final stdoutTail = stdoutLineCount <= tailN
        ? stdout
        : stdoutLines
            .skip(stdoutLineCount - tailN)
            .join('\n');

    final buf = StringBuffer()
      ..writeln('Command failed (exit $exitCode).')
      ..writeln('stderr ($stderrSizeKb KB):')
      ..writeln(stderrShown.isEmpty ? '(empty)' : stderrShown)
      ..writeln('stdout (last $tailN lines of $stdoutLineCount):')
      ..writeln(stdoutTail.isEmpty ? '(empty)' : stdoutTail);
    _appendRecoveryFooter(buf, teePath);
    return buf.toString();
  }

  void _appendRecoveryFooter(StringBuffer buf, String? teePath) {
    if (teePath != null && teePath.isNotEmpty) {
      buf.writeln('Full log: $teePath');
    }
  }

  String _additionalContext({required String? teePath}) {
    final buf = StringBuffer(
      'Bash output was filtered by flart. ',
    );
    if (teePath != null && teePath.isNotEmpty) {
      buf.write('Full log at $teePath. ');
    }
    buf.write(
        'To bypass on the next run, prefix the command with FLART_FULL_OUTPUT=1, '
        'or read the tee log directly (cat/head/tail/grep on the path above '
        'are auto-passed through).');
    return buf.toString();
  }
}
