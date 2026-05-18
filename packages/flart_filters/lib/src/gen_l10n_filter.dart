import 'filter.dart';
import 'filter_result.dart';

/// `flart gen-l10n` — wraps `flutter gen-l10n`. Plan 5.4.6.
///
/// Output shapes:
///   - Success: `Generated to: lib/l10n/` (+ generated file lines).
///   - Untranslated key warnings grouped per locale.
///   - Misconfigured project: a single error block (no `flutter: generate:`).
class GenL10nFilter implements CommandFilter {
  @override
  String get name => 'gen_l10n';

  @override
  String get flartCommand => 'gen-l10n';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      const ['flutter', 'gen-l10n'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  static final RegExp _generatedRegex =
      RegExp(r'^Generated to:?\s*(.+)$', multiLine: true);
  // Locale names in Flutter's gen-l10n warnings appear inside single quotes.
  static final RegExp _untranslatedRegex =
      RegExp(r"Found .*untranslated.*'([a-zA-Z_]+)'");

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    if (exitCode != 0) {
      final body = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
      return FilterResult(
        output: 'FAILED: gen-l10n (exit $exitCode)\n${body.split('\n').take(5).join('\n')}',
        metadata: {'failed': true},
      );
    }

    final generatedMatch = _generatedRegex.firstMatch(stdout);
    final missingByLocale = <String, int>{};
    for (final m in _untranslatedRegex.allMatches(stdout)) {
      final locale = m.group(1)!;
      missingByLocale[locale] = (missingByLocale[locale] ?? 0) + 1;
    }

    final buf = StringBuffer();
    if (generatedMatch != null) {
      buf.writeln('ok (generated to: ${generatedMatch.group(1)!.trim()})');
    } else {
      buf.writeln('ok');
    }
    if (missingByLocale.isNotEmpty) {
      buf.writeln();
      buf.writeln('Untranslated keys:');
      for (final entry in missingByLocale.entries) {
        buf.writeln('  ${entry.key}: ${entry.value}');
      }
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: {
        'failed': false,
        'locales_with_missing': missingByLocale.length,
        'untranslated_total':
            missingByLocale.values.fold<int>(0, (a, b) => a + b),
      },
    );
  }
}
