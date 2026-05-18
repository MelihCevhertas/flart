// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

void main() {
  group('GenL10nFilter', () {
    test('success path extracts generated path', () {
      const stdout = 'Resolving... done.\nGenerated to: lib/l10n/\n';
      final r = GenL10nFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('ok'));
      expect(r.output, contains('lib/l10n/'));
      expect(r.metadata['failed'], isFalse);
    });

    test('untranslated key warnings grouped by locale', () {
      const stdout = '''
Resolving... done.
Generated to: lib/l10n/
Warning: Found untranslated messages for locale 'tr'.
Warning: Found untranslated messages for locale 'tr'.
Warning: Found untranslated messages for locale 'de'.
''';
      final r = GenL10nFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('Untranslated keys:'));
      expect(r.output, contains('tr: 2'));
      expect(r.output, contains('de: 1'));
      expect(r.metadata['locales_with_missing'], 2);
      expect(r.metadata['untranslated_total'], 3);
    });

    test('configuration error surfaces as FAILED', () {
      final r = GenL10nFilter().filter(
        stdout: '',
        stderr:
            'Attempted to generate localizations code without having the flutter: generate flag turned on.',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, contains('FAILED'));
      expect(r.output, contains('flutter: generate'));
      expect(r.metadata['failed'], isTrue);
    });

    test('CommandFilter contract', () {
      final f = GenL10nFilter();
      expect(f.name, 'gen_l10n');
      expect(f.flartCommand, 'gen-l10n');
      expect(f.baseNativeCommand(const []), ['flutter', 'gen-l10n']);
    });
  });
}
