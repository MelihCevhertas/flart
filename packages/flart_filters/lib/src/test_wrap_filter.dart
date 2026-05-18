import 'filter.dart';
import 'filter_result.dart';

/// `flart test-wrap <command...>` — generic test wrapper. Plan Section 5.5.
///
/// For test runners without a structured reporter, parse the text summary
/// (`X passed`, `Y failed`, `Z tests`) and surface only counts + the few
/// failure-marker lines.
class TestWrapFilter implements CommandFilter {
  @override
  String get name => 'test_wrap';

  @override
  String get flartCommand => 'test-wrap';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      userArgs.isEmpty ? const ['true'] : userArgs;

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  static final RegExp _passedRegex = RegExp(r'(\d+)\s+(?:tests?\s+)?passed');
  static final RegExp _failedRegex = RegExp(r'(\d+)\s+(?:tests?\s+)?failed');
  static final RegExp _skippedRegex = RegExp(r'(\d+)\s+(?:tests?\s+)?skipped');
  // Word-boundary only makes sense after FAIL (an alphabetic token). The
  // unicode markers ✗ / × are non-word characters; `\b` after them won't
  // fire on subsequent text. Split the alternation accordingly.
  static final RegExp _failingLineRegex =
      RegExp(r'^\s*(?:FAIL\b|[✗×])');

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final combined = '$stdout\n$stderr';
    int lastInt(RegExp re) {
      int? hit;
      for (final m in re.allMatches(combined)) {
        hit = int.tryParse(m.group(1)!);
      }
      return hit ?? 0;
    }

    final passed = lastInt(_passedRegex);
    final failed = lastInt(_failedRegex);
    final skipped = lastInt(_skippedRegex);
    final failingLines = <String>[];
    for (final raw in combined.split('\n')) {
      final line = raw.trimRight();
      if (_failingLineRegex.hasMatch(line)) failingLines.add(line);
    }

    final total = passed + failed + skipped;
    final buf = StringBuffer();
    if (exitCode == 0 && failed == 0) {
      buf.write('PASSED $passed/$total tests');
      if (skipped > 0) buf.write(' ($skipped skipped)');
    } else {
      buf.writeln('FAILED $failed/$total tests');
      if (failingLines.isNotEmpty) {
        buf.writeln();
        for (final l in failingLines.take(15)) {
          buf.writeln(l);
        }
      }
      buf.write(
        'Passed: $passed  Failed: $failed  Skipped: $skipped  Exit: $exitCode',
      );
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: {
        'passed': passed,
        'failed': failed,
        'skipped': skipped,
        'wrapped_exit': exitCode,
      },
    );
  }
}
