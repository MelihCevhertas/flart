// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

import 'fixture_helper.dart';

void main() {
  group('DoctorFilter — fixture-driven', () {
    test('partial fixture: keeps [!] category with sub-bullets, collapses [✓]',
        () {
      final body = readFixture('doctor_partial.txt');
      final r = DoctorFilter().filter(
        stdout: body,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('! Android toolchain'));
      expect(r.output, contains('Some Android licenses not accepted'));
      // [✓] categories collapsed into the summary line.
      expect(r.output, isNot(contains('[✓] Flutter')));
      expect(r.output, isNot(contains('Channel stable')));
      // Counts.
      expect(r.output, contains('5 ok'));
      expect(r.output, contains('! 1 partial'));
      expect(r.metadata['ok'], 5);
      expect(r.metadata['partial'], 1);
      expect(r.metadata['missing'], 0);
    });
  });

  group('DoctorFilter — synthetic edge cases', () {
    test('all-healthy run collapses to "All N categories healthy."', () {
      const stdout = '''
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter
[✓] Xcode
[✓] Connected device
''';
      final r = DoctorFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('All 3 categories healthy'));
      expect(r.metadata['ok'], 3);
    });

    test('missing category keeps full sub-bullet detail', () {
      const stdout = '''
Doctor summary:
[✓] Flutter
[✗] Xcode - develop for iOS and macOS
    • Xcode not installed; download from the App Store
    • Run sudo xcode-select --switch
[✓] Chrome

! Doctor found issues in 1 category.
''';
      final r = DoctorFilter().filter(
        stdout: stdout,
        stderr: '',
        exitCode: 0,
        userArgs: const [],
      );
      expect(r.output, contains('✗ Xcode'));
      expect(r.output, contains('Xcode not installed'));
      expect(r.output, contains('sudo xcode-select'));
      expect(r.metadata['missing'], 1);
    });
  });

  group('DoctorFilter — CommandFilter contract', () {
    test('name + baseNativeCommand', () {
      final f = DoctorFilter();
      expect(f.name, 'doctor');
      expect(f.flartCommand, 'doctor');
      expect(f.baseNativeCommand(const []), ['flutter', 'doctor']);
    });
  });
}
