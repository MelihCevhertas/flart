// ignore_for_file: depend_on_referenced_packages

import 'package:flart_executor/flart_executor.dart';
import 'package:test/test.dart';

void main() {
  group('ExecResult', () {
    test('defaults timedOut and wasTruncated to false', () {
      const r = ExecResult(stdout: 'ok', stderr: '', exitCode: 0);
      expect(r.timedOut, isFalse);
      expect(r.wasTruncated, isFalse);
    });

    test('toString includes byte counts and flags', () {
      const r = ExecResult(
        stdout: 'hello',
        stderr: '',
        exitCode: 0,
        timedOut: true,
        wasTruncated: true,
      );
      final s = r.toString();
      expect(s, contains('exitCode: 0'));
      expect(s, contains('timedOut: true'));
      expect(s, contains('wasTruncated: true'));
      expect(s, contains('stdoutBytes: 5'));
    });
  });

  group('Exception types', () {
    test('ImportValidationException.toString returns message', () {
      const e = ImportValidationException('bad import');
      expect(e.toString(), 'bad import');
      expect(e, isA<ExecException>());
    });

    test('RuntimeNotFoundException.toString returns message', () {
      const e = RuntimeNotFoundException('not found');
      expect(e.toString(), 'not found');
      expect(e, isA<ExecException>());
    });
  });
}
