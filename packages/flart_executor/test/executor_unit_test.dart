// ignore_for_file: depend_on_referenced_packages

import 'package:flart_executor/flart_executor.dart';
import 'package:test/test.dart';

void main() {
  group('SandboxExecutor pre-flight checks', () {
    test('Dart code with package: import throws ImportValidationException',
        () async {
      // Use a detector that would succeed if reached, to prove the validator
      // fires *before* PATH lookup.
      final exec = SandboxExecutor(
        detector: RuntimeDetector(exists: (_) async => true),
      );
      expect(
        () => exec.execute(
          runtime: Runtime.dart,
          code: "import 'package:foo/foo.dart';\nvoid main() {}",
        ),
        throwsA(isA<ImportValidationException>().having(
          (e) => e.toString(),
          'message',
          contains('mod A'),
        )),
      );
    });

    test('missing runtime throws RuntimeNotFoundException with hints',
        () async {
      final exec = SandboxExecutor(
        detector: RuntimeDetector(exists: (_) async => false),
      );
      expect(
        () => exec.execute(runtime: Runtime.python, code: 'print(1)'),
        throwsA(isA<RuntimeNotFoundException>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains("'python' not found in PATH"),
            contains('Tried: python3, python'),
          ),
        )),
      );
    });

    test('runtime-not-found messages mention install paths', () async {
      final exec = SandboxExecutor(
        detector: RuntimeDetector(exists: (_) async => false),
      );
      for (final entry in {
        Runtime.dart: 'dart.dev',
        Runtime.bash: 'package manager',
        Runtime.python: 'Python 3',
        Runtime.node: 'nodejs.org',
      }.entries) {
        try {
          await exec.execute(runtime: entry.key, code: 'noop');
          fail('expected RuntimeNotFoundException for ${entry.key}');
        } on RuntimeNotFoundException catch (e) {
          expect(e.toString(), contains(entry.value),
              reason: '${entry.key} message');
        }
      }
    });
  });
}
