// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flart_cli/runner.dart';
import 'package:test/test.dart';

/// Runs [body] inside a zone that captures `print` calls into [out].
Future<int> _captureRun(
  StringBuffer out,
  Future<int> Function() body,
) async {
  return runZoned<Future<int>>(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, line) => out.writeln(line),
    ),
  );
}

void main() {
  group('runFlart', () {
    test('"version" prints flart <semver> and exits 0', () async {
      final out = StringBuffer();
      final code = await _captureRun(out, () => runFlart(['version']));
      expect(code, 0);
      expect(out.toString().trim(), 'flart 0.2.0-dev');
    });

    test('empty args print top-level help including subcommands', () async {
      final out = StringBuffer();
      final code = await _captureRun(out, () => runFlart(const []));
      expect(code, 0);
      final s = out.toString();
      expect(s, contains('flart'));
      expect(s, contains('Available commands'));
      expect(s, contains('version'));
    });

    test('--help prints usage', () async {
      final out = StringBuffer();
      final code = await _captureRun(out, () => runFlart(['--help']));
      expect(code, 0);
      expect(out.toString(), contains('Token-optimization CLI'));
    });

    test('unknown command returns flart-internal parse-error code 100',
        () async {
      final out = StringBuffer();
      final code =
          await _captureRun(out, () => runFlart(['definitely-not-a-command']));
      expect(code, 100);
    });

    test('-v and -q flags are accepted at the top level', () async {
      final out = StringBuffer();
      // Combined with `version` they should both parse cleanly even though
      // nothing consumes them yet.
      final code1 = await _captureRun(out, () => runFlart(['-v', 'version']));
      final code2 = await _captureRun(out, () => runFlart(['-q', 'version']));
      expect(code1, 0);
      expect(code2, 0);
    });
  });
}
