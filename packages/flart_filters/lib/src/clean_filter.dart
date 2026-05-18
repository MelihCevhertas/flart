import 'filter.dart';
import 'filter_result.dart';

/// `flart clean` — wraps `flutter clean`. Plan 5.2 (95%+ savings target).
///
/// `flutter clean` either succeeds and prints "Deleting build..." spam, or
/// fails and prints a useful error. We collapse the success case to a single
/// "ok" line; on failure we keep the first few lines of stderr as a hint.
class CleanFilter implements CommandFilter {
  @override
  String get name => 'clean';

  @override
  String get flartCommand => 'clean';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      const ['flutter', 'clean'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    if (exitCode == 0) {
      return const FilterResult(
        output: 'ok',
        metadata: {'failed': false},
      );
    }
    final hint = stderr.trim().split('\n').take(5).join('\n');
    final body = hint.isEmpty
        ? 'FAILED: flutter clean (exit $exitCode)'
        : 'FAILED: flutter clean (exit $exitCode)\n$hint';
    return FilterResult(
      output: body,
      metadata: {'failed': true},
    );
  }
}
