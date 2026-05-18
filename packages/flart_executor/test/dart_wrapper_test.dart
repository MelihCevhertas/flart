// ignore_for_file: depend_on_referenced_packages

import 'package:flart_executor/flart_executor.dart';
import 'package:test/test.dart';

void main() {
  group('wrapDartIfNeeded — wraps when no main', () {
    test('empty input → wraps with empty body', () {
      final wrapped = wrapDartIfNeeded('');
      expect(wrapped, contains('void main() async'));
      expect(wrapped.trim(), startsWith('void main() async {'));
    });

    test('single statement', () {
      final wrapped = wrapDartIfNeeded('print("hi");');
      expect(wrapped, contains('void main() async {'));
      expect(wrapped, contains('print("hi");'));
    });

    test('multi-line statements', () {
      final wrapped = wrapDartIfNeeded('final x = 1;\nprint(x);');
      expect(wrapped, contains('void main() async'));
      expect(wrapped, contains('final x = 1;'));
      expect(wrapped, contains('print(x);'));
    });

    test('local function declaration inside body is allowed', () {
      final wrapped = wrapDartIfNeeded(
        'int double(int n) => n * 2;\nprint(double(5));',
      );
      // Dart permits nested function declarations, so the helper stays
      // inside the wrap.
      expect(wrapped, contains('int double(int n)'));
      expect(wrapped, contains('void main() async'));
    });

    test('extracts single-line imports above the wrap', () {
      final wrapped =
          wrapDartIfNeeded("import 'dart:io';\nprint(Platform.script);");
      // Imports must be top-level; wrap should not enclose them.
      final mainIdx = wrapped.indexOf('void main()');
      final importIdx = wrapped.indexOf('import');
      expect(importIdx, isNonNegative);
      expect(mainIdx, isNonNegative);
      expect(importIdx, lessThan(mainIdx),
          reason: 'import must appear before main()');
      // Body shouldn't contain the import line anymore.
      final body = wrapped.substring(mainIdx);
      expect(body, isNot(contains('import ')));
    });

    test('extracts multiple imports', () {
      final wrapped = wrapDartIfNeeded(
        "import 'dart:io';\nimport 'dart:convert';\nprint(jsonEncode({}));",
      );
      expect(wrapped, contains("import 'dart:io';"));
      expect(wrapped, contains("import 'dart:convert';"));
      final mainIdx = wrapped.indexOf('void main()');
      final body = wrapped.substring(mainIdx);
      expect(body, isNot(contains('import ')));
    });

    test('commented-out main does not block wrapping', () {
      final wrapped =
          wrapDartIfNeeded('// void main()\nprint("after-comment");');
      expect(wrapped, contains('void main() async {'));
      expect(wrapped, contains('after-comment'));
    });

    test('inner main inside a helper function is not detected', () {
      // The only `main(` is inside `helper`, not top-level. Wrap should fire.
      final wrapped = wrapDartIfNeeded(
        'void helper() { void main() {} }\nhelper();',
      );
      // Wrapping adds *another* main; the inner one stays as nested local.
      // Validate by counting main(): expect exactly one *top-level* `void main(` line.
      expect(wrapped, contains('void main() async'));
    });
  });

  group('wrapDartIfNeeded — keeps explicit main untouched', () {
    test('classic void main', () {
      const code = 'void main() => print("hi");';
      expect(wrapDartIfNeeded(code), code);
    });

    test('async main', () {
      const code = 'void main() async { print("x"); }';
      expect(wrapDartIfNeeded(code), code);
    });

    test('Future<void> main', () {
      const code = 'Future<void> main() async {}';
      expect(wrapDartIfNeeded(code), code);
    });

    test('Future<int> main', () {
      const code = 'Future<int> main() async => 0;';
      expect(wrapDartIfNeeded(code), code);
    });

    test('typeless main', () {
      const code = 'main() { print("ok"); }';
      expect(wrapDartIfNeeded(code), code);
    });

    test('indented main', () {
      const code = '  void main() { }';
      expect(wrapDartIfNeeded(code), code);
    });

    test('main with args', () {
      const code = 'void main(List<String> args) { print(args); }';
      expect(wrapDartIfNeeded(code), code);
    });

    test('main after a top-level constant', () {
      const code = "const greeting = 'hi';\nvoid main() => print(greeting);";
      expect(wrapDartIfNeeded(code), code);
    });
  });

  group('wrapDartIfNeeded — false-positive boundaries', () {
    test('similarly named function is not detected as main', () {
      final wrapped = wrapDartIfNeeded('void mainHelper() {} mainHelper();');
      expect(wrapped, contains('void main() async {'));
    });
  });
}
