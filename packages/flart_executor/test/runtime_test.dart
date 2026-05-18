// ignore_for_file: depend_on_referenced_packages

import 'package:flart_executor/flart_executor.dart';
import 'package:test/test.dart';

void main() {
  group('Runtime.resolve', () {
    test('canonical names', () {
      expect(Runtime.resolve('dart'), Runtime.dart);
      expect(Runtime.resolve('bash'), Runtime.bash);
      expect(Runtime.resolve('python'), Runtime.python);
      expect(Runtime.resolve('node'), Runtime.node);
    });

    test('aliases', () {
      expect(Runtime.resolve('sh'), Runtime.bash);
      expect(Runtime.resolve('python3'), Runtime.python);
      expect(Runtime.resolve('js'), Runtime.node);
      expect(Runtime.resolve('javascript'), Runtime.node);
    });

    test('case-insensitive and whitespace-trimmed', () {
      expect(Runtime.resolve('  DART '), Runtime.dart);
      expect(Runtime.resolve('JavaScript'), Runtime.node);
    });

    test('unknown runtime throws ArgumentError with hints', () {
      try {
        Runtime.resolve('ruby');
        fail('expected ArgumentError');
      } on ArgumentError catch (e) {
        expect(e.message, contains("Unknown runtime 'ruby'"));
        expect(e.message, contains('Supported:'));
        expect(e.message, contains('dart'));
        expect(e.message, contains('python3'));
      }
    });
  });

  group('Runtime.scriptExtension', () {
    test('one extension per runtime', () {
      expect(Runtime.dart.scriptExtension, 'dart');
      expect(Runtime.bash.scriptExtension, 'sh');
      expect(Runtime.python.scriptExtension, 'py');
      expect(Runtime.node.scriptExtension, 'js');
    });
  });

  group('RuntimeDetector', () {
    test('python tries python3 before python', () async {
      final seen = <String>[];
      final detector = RuntimeDetector(exists: (exe) async {
        seen.add(exe);
        return exe == 'python';
      });
      final result = await detector.detect(Runtime.python);
      expect(result, 'python');
      expect(seen, ['python3', 'python']);
    });

    test('returns first match for python candidates', () async {
      final detector =
          RuntimeDetector(exists: (exe) async => exe == 'python3');
      expect(await detector.detect(Runtime.python), 'python3');
    });

    test('returns null when no candidate exists', () async {
      final detector = RuntimeDetector(exists: (exe) async => false);
      expect(await detector.detect(Runtime.python), isNull);
      expect(await detector.detect(Runtime.node), isNull);
    });

    test('dart/bash/node each have a single candidate', () {
      expect(RuntimeDetector.candidates(Runtime.dart), ['dart']);
      expect(RuntimeDetector.candidates(Runtime.bash), ['bash']);
      expect(RuntimeDetector.candidates(Runtime.node), ['node']);
    });

    test('python candidates: python3 first, python second', () {
      expect(RuntimeDetector.candidates(Runtime.python), ['python3', 'python']);
    });
  });
}
