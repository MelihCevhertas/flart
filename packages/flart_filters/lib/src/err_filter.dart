import 'filter.dart';
import 'filter_result.dart';

/// `flart err <command...>` — generic wrapper that runs *any* command and
/// keeps only error-pattern lines plus the surrounding stack-trace context.
/// Plan Section 5.5.
///
/// Patterns kept:
/// - `error:`, `ERROR:`, `Error:` lines.
/// - `FAIL`, `FAILED`, `failed:` markers.
/// - `<file>:<line>:<col>` style locations.
/// - Stack-trace lines (`at `, `#<n>`, `package:`, `<asynchronous suspension>`)
///   that immediately follow one of the above.
class ErrFilter implements CommandFilter {
  @override
  String get name => 'err';

  @override
  String get flartCommand => 'err';

  /// The wrapped command is just `userArgs` verbatim — `flart err <cmd...>`
  /// passes everything after the subcommand straight to Process.start.
  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      userArgs.isEmpty ? const ['true'] : userArgs;

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  static final RegExp _markerRegex = RegExp(
    r'(error[: ]|ERROR[: ]|Error[: ]|FAIL(?:URE|ED)?\b|failed:)',
  );
  static final RegExp _locationRegex =
      RegExp(r'^\s*[^\s:]+:[\d]+:[\d]+\b');
  static final RegExp _stackFrameRegex = RegExp(
    r'^\s*(at |#\d+\s|package:|file://|<asynchronous suspension>)',
  );

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final kept = <String>[];
    // Sticky context window: after a marker line we accept one
    // continuation message line, then chain stack frames until either a
    // blank line or a non-stack non-marker line.
    int contextAvailable = 0;
    final lines =
        '$stdout${stdout.endsWith('\n') ? '' : '\n'}$stderr'.split('\n');
    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        contextAvailable = 0;
        continue;
      }
      if (_markerRegex.hasMatch(line) || _locationRegex.hasMatch(line)) {
        kept.add(line);
        contextAvailable = 2; // 1 message + 1+ stack frames
        continue;
      }
      if (contextAvailable >= 2) {
        // Continuation message line (e.g. compiler diagnostic body).
        kept.add(line);
        contextAvailable = 1;
        continue;
      }
      if (contextAvailable == 1 && _stackFrameRegex.hasMatch(line)) {
        // Chained stack frames stay at 1 so the chain extends.
        kept.add(line);
        continue;
      }
      contextAvailable = 0;
    }
    final body = kept.isEmpty
        ? (exitCode == 0
            ? 'no errors detected'
            : 'exit $exitCode (no recognised error markers)')
        : kept.join('\n');
    return FilterResult(
      output: body,
      metadata: {'matches': kept.length, 'wrapped_exit': exitCode},
    );
  }
}
