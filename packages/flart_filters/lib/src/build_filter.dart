import 'filter.dart';
import 'filter_result.dart';
import 'filter_utils.dart';

/// `flart build <target>` — wraps `flutter build apk|web|ipa`. Plan 5.4.3.
///
/// Modern Flutter emits very compact stdout on success (one or two lines).
/// The real raw weight on failure is on **stderr** — Dart compile errors
/// (`file:line:col: Error: message`) followed by a Gradle/Xcode FAILURE
/// block. This filter:
///
/// - On exit 0: extracts the `✓ Built <path>` line + any captured timing.
/// - On exit != 0: collects compile-error blocks from stderr, includes a
///   short FAILURE summary, and lets the runner's tee carry the full log.
///
/// `target` is one of `'apk'`, `'web'`, `'ipa'`. Determines the native
/// `flutter build <target>` invocation and the failure-summary wording.
class BuildFilter implements CommandFilter {
  /// One of `apk`, `web`, `ipa`. Set by the CLI from the subcommand name.
  final String target;

  /// Per-issue message length cap (compile errors can be long).
  final int truncateMessagesAt;

  BuildFilter({required this.target, this.truncateMessagesAt = 300});

  @override
  String get name => 'build_$target';

  @override
  String get flartCommand => 'build';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      ['flutter', 'build', target];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    // ---- success path ----
    final builtMatch = _builtRegex.firstMatch(stdout);
    if (exitCode == 0 && builtMatch != null) {
      final outputPath = builtMatch.group(1)!.trim();
      final sizeHint = builtMatch.group(2)?.trim();
      final totalTime = _extractTotalTime(stdout);
      final headerParts = ['✓ Built $outputPath'];
      if (sizeHint != null && sizeHint.isNotEmpty) {
        headerParts[0] = '${headerParts[0]} ($sizeHint)';
      }
      final metadata = <String, Object?>{
        'target': target,
        'success': true,
        'output_path': outputPath,
        if (sizeHint != null) 'size_hint': sizeHint,
        if (totalTime != null) 'duration': totalTime,
      };
      final body = totalTime != null
          ? '${headerParts.first}\n  $totalTime'
          : headerParts.first;
      return FilterResult(output: body, metadata: metadata);
    }

    // ---- failure path ----
    final errors = _extractCompileErrors(stderr);
    final failureLine = _extractFailureLine(stderr);

    final buf = StringBuffer('✗ Build failed ($target');
    if (failureLine != null) {
      buf.write(', $failureLine');
    } else if (exitCode != 0) {
      buf.write(', exit $exitCode');
    }
    buf.writeln(')');

    if (errors.isNotEmpty) {
      buf.writeln();
      for (final e in errors) {
        final msg = FilterUtils.truncateMessage(e.message, truncateMessagesAt);
        buf.writeln('ERROR: ${e.location}');
        buf.writeln('  $msg');
      }
    }

    final metadata = <String, Object?>{
      'target': target,
      'success': false,
      'errors': errors.length,
      if (failureLine != null) 'failure_line': failureLine,
    };
    return FilterResult(output: buf.toString().trimRight(), metadata: metadata);
  }

  /// `✓ Built <path> [(<size>)]` — captures the final artifact line.
  /// The size suffix is optional (modern `flutter build apk --debug` omits
  /// it; release builds typically include `(X.X MB)`).
  static final RegExp _builtRegex = RegExp(
    r'(?:^|\n)✓ Built ([^\s][^\n(]*?)(?:\s*\(([^)]*)\))?\s*$',
    multiLine: true,
  );

  /// Matches the trailing "Xs"/"X,Ys"/"X.Ys" duration on status lines like:
  ///   `Running Gradle task 'assembleDebug'...                          47s`
  ///   `Compiling lib/main.dart for the Web...                          13,2s`
  static final RegExp _timingRegex = RegExp(
    r'^(?:Running Gradle task|Compiling)[^\n]*?(\d+[\.,]?\d*s)\s*$',
    multiLine: true,
  );

  /// Dart frontend compile error:
  ///   `lib/main.dart:3:12: Error: A value of type 'int' can't be ...`
  static final RegExp _dartErrorRegex = RegExp(
    r'^([^\s:][^:\n]*?\.dart):(\d+):(\d+):\s*Error:\s*(.+)$',
    multiLine: true,
  );

  static String? _extractTotalTime(String stdout) {
    String? last;
    for (final m in _timingRegex.allMatches(stdout)) {
      last = m.group(1);
    }
    return last == null ? null : 'Build time: $last';
  }

  static List<_BuildError> _extractCompileErrors(String stderr) {
    final out = <_BuildError>[];
    for (final m in _dartErrorRegex.allMatches(stderr)) {
      out.add(_BuildError(
        location: '${m.group(1)}:${m.group(2)}:${m.group(3)}',
        message: m.group(4)!.trim(),
      ));
    }
    return out;
  }

  /// Pulls the most informative failure summary line. Gradle uses
  /// `BUILD FAILED in <X>s`; iOS/Xcode tends to use `** BUILD FAILED **`.
  /// We prefer the canonical "BUILD FAILED" marker over the secondary
  /// "Gradle task X failed" line when both are present.
  static String? _extractFailureLine(String stderr) {
    String? gradleTaskFallback;
    for (final line in stderr.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('BUILD FAILED') || t.startsWith('** BUILD FAILED')) {
        return t;
      }
      if (t.startsWith('Gradle task ') && t.contains('failed')) {
        gradleTaskFallback = t;
      }
    }
    return gradleTaskFallback;
  }
}

class _BuildError {
  final String location;
  final String message;
  const _BuildError({required this.location, required this.message});
}
