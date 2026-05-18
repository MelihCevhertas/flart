// ignore_for_file: depend_on_referenced_packages

import 'package:flart_executor/flart_executor.dart';
import 'package:test/test.dart';

void main() {
  group('validateDartImports', () {
    test('accepts dart:* imports', () {
      const code = '''
import 'dart:io';
import 'dart:convert';
import 'dart:async';
void main() => print('ok');
''';
      expect(validateDartImports(code), isNull);
    });

    test('accepts code without imports', () {
      const code = "void main() => print('hello');";
      expect(validateDartImports(code), isNull);
    });

    test('rejects package: imports', () {
      const code = "import 'package:http/http.dart' as http;";
      final err = validateDartImports(code);
      expect(err, isNotNull);
      expect(err, contains('package:'));
      expect(err, contains('mod A'));
      expect(err, contains('Use bash/python'));
    });

    test('rejects parent-relative imports', () {
      const code = "import '../shared/utils.dart';";
      expect(validateDartImports(code), isNotNull);
    });

    test('rejects current-dir relative imports', () {
      const code = "import './local.dart';";
      expect(validateDartImports(code), isNotNull);
    });

    test('rejects double-quoted package: imports', () {
      const code = 'import "package:foo/foo.dart";';
      expect(validateDartImports(code), isNotNull);
    });

    test('finds offending import even after dart:* imports', () {
      const code = '''
import 'dart:io';
import 'package:provider/provider.dart';
void main() {}
''';
      expect(validateDartImports(code), isNotNull);
    });

    test('matches when import has leading whitespace', () {
      const code = "    import 'package:foo/foo.dart';";
      expect(validateDartImports(code), isNotNull);
    });

    test('ignores import-like text inside string literals', () {
      const code = '''
void main() {
  final s = "import 'package:fake';";
  print(s);
}
''';
      expect(validateDartImports(code), isNull);
    });
  });
}
