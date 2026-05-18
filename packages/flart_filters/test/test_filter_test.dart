// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('TestFilter — fixture-driven', () {
    test('all-pass fixture collapses to one PASSED line', () {
      final body = readFixture('test_all_pass.json');
      final r = TestFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, startsWith('PASSED '));
      expect(r.output, contains('/'));
      expect(r.output, contains('s'));
      expect(r.metadata['failed'], 0);
      expect(r.metadata['error'], 0);
      expect(r.metadata['passed'], 3);
      expect(r.metadata['tests_total'], 3);
    });

    test('some-fail fixture renders FAILED block with names + errors', () {
      final body = readFixture('test_some_fail.json');
      final r = TestFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 1,
        userArgs: const [],
      );
      expect(r.output, startsWith('FAILED '));
      // Two failures from the lab: assertion failure + exception.
      expect(r.output, contains('fail-string'));
      expect(r.output, contains('fail-throws'));
      expect(r.output, contains('Expected: '));
      expect(r.output, contains('boom from the test'));
      // Suite path heading + summary line.
      expect(r.output, contains('✗ '));
      expect(r.output, contains('Passed: 2'));
      expect(r.output, contains('Failed: 1'));
      expect(r.output, contains('Error: 1'));
      expect(r.metadata['tests_total'], 4);
      expect(r.metadata['passed'], 2);
      expect(r.metadata['failed'], 1);
      expect(r.metadata['error'], 1);
    });
  });

  group('TestFilter — defensive parsing', () {
    test('ignores non-JSON lines and unknown event types', () {
      const stdout = '''
random pre-amble line
{"type":"start","time":0,"protocolVersion":"0.1.1"}
{"type":"weird-future-event","payload":{"x":1}}
{"type":"suite","time":0,"suite":{"id":0,"path":"test/x_test.dart","platform":"vm"}}
{"type":"testStart","time":1,"test":{"id":1,"name":"loading test/x_test.dart","suiteID":0,"groupIDs":[],"line":null,"column":null,"url":null}}
{"type":"testDone","time":2,"testID":1,"result":"success","skipped":false,"hidden":true}
{"type":"testStart","time":3,"test":{"id":2,"name":"only test","suiteID":0,"groupIDs":[3],"line":1,"column":1,"url":"file:///x_test.dart"}}
{"type":"testDone","time":4,"testID":2,"result":"success","skipped":false,"hidden":false}
{"type":"done","time":5,"success":true}
trailing garbage line
''';
      final r = TestFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, startsWith('PASSED 1/1'));
      expect(r.metadata['tests_total'], 1);
    });

    test('malformed JSON line is silently skipped', () {
      const stdout = '''
{"type":"start","time":0,"protocolVersion":"0.1.1"}
{"type":"suite","suite":{"id":0,"path":"x","platform":"vm"}
{"type":"testStart","time":1,"test":{"id":2,"name":"t","suiteID":0,"groupIDs":[3]}}
{"type":"testDone","time":2,"testID":2,"result":"success"}
{"type":"done","time":3,"success":true}
''';
      final r = TestFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.metadata['tests_total'], 1);
      expect(r.output, startsWith('PASSED'));
    });
  });

  group('TestFilter — CommandFilter contract', () {
    test('default (Flutter) baseNativeCommand', () {
      final f = TestFilter();
      expect(f.name, 'test');
      expect(f.flartCommand, 'test');
      expect(
        f.baseNativeCommand(const []),
        ['flutter', 'test', '--reporter=json'],
      );
    });

    test('pure-Dart baseNativeCommand uses `dart test`', () {
      final f = TestFilter(isFlutterProject: false);
      expect(
        f.baseNativeCommand(const []),
        ['dart', 'test', '--reporter=json'],
      );
    });
  });
}
