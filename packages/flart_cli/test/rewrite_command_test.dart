// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flart_cli/runner.dart';
import 'package:test/test.dart';

class _CapturingSink implements IOSink {
  final StringBuffer buffer = StringBuffer();
  @override
  Encoding encoding = utf8;
  @override
  void write(Object? o) => buffer.write(o);
  @override
  void writeln([Object? o = '']) => buffer.writeln(o);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int c) => buffer.write(String.fromCharCode(c));
  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));
  @override
  void addError(Object e, [StackTrace? s]) {}
  @override
  Future<void> addStream(Stream<List<int>> s) async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> get done => Future.value();
}

Future<({int code, String stdout, String stderr})> _run(
  List<String> args,
) async {
  final out = _CapturingSink();
  final err = _CapturingSink();
  final code = await runFlart(
    args,
    stdoutOverride: out,
    stderrOverride: err,
  );
  return (
    code: code,
    stdout: out.buffer.toString(),
    stderr: err.buffer.toString(),
  );
}

void main() {
  group('flart rewrite', () {
    test('flutter analyze → flart analyze, exit 0', () async {
      final r = await _run(['rewrite', 'flutter analyze']);
      expect(r.code, 0);
      expect(r.stdout.trim(), 'flart analyze');
    });

    test('preserves cd prefix', () async {
      final r = await _run(['rewrite', 'cd /tmp && flutter test']);
      expect(r.code, 0);
      expect(r.stdout.trim(), 'cd /tmp && flart test');
    });

    test('pipe → passthrough (same output as input)', () async {
      final r = await _run(['rewrite', 'flutter analyze | tee out.txt']);
      expect(r.code, 0);
      expect(r.stdout.trim(), 'flutter analyze | tee out.txt');
    });

    test('unknown command → passthrough', () async {
      final r = await _run(['rewrite', 'git status']);
      expect(r.code, 0);
      expect(r.stdout.trim(), 'git status');
    });

    test('empty input → exit 1 with stderr usage', () async {
      final r = await _run(['rewrite']);
      expect(r.code, 1);
      expect(r.stderr, contains('missing command'));
    });

    test('dart fix --apply preserved', () async {
      final r = await _run(['rewrite', 'dart fix --apply']);
      expect(r.code, 0);
      expect(r.stdout.trim(), 'flart fix --apply');
    });

    test('flutter build apk with flags', () async {
      final r = await _run(['rewrite', 'flutter build apk --release']);
      expect(r.code, 0);
      expect(r.stdout.trim(), 'flart build apk --release');
    });
  });
}
