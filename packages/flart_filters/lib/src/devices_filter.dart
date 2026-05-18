import 'filter.dart';
import 'filter_result.dart';

/// `flart devices` — wraps `flutter devices`. Plan 5.4 (target band 50-70%,
/// already-low expectation: device output is short).
///
/// Keeps the device rows (centered around the `•` separators), drops the
/// "Run flutter emulators…" footer and the diagnostics paragraph.
class DevicesFilter implements CommandFilter {
  @override
  String get name => 'devices';

  @override
  String get flartCommand => 'devices';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      const ['flutter', 'devices'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  static final RegExp _foundRegex =
      RegExp(r'^Found (\d+) connected device', multiLine: true);

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    if (exitCode != 0) {
      return FilterResult(
        output: 'FAILED: devices (exit $exitCode)\n${stderr.trim()}',
        metadata: {'failed': true},
      );
    }
    final foundMatch = _foundRegex.firstMatch(stdout);
    final found = foundMatch != null
        ? int.tryParse(foundMatch.group(1)!) ?? 0
        : 0;

    final devices = <String>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      // Device rows always contain at least three `•` separators.
      if (line.split('•').length >= 3) {
        devices.add(line);
      }
    }
    if (devices.isEmpty) {
      return FilterResult(
        output: 'no devices connected',
        metadata: {'found': 0},
      );
    }
    final buf = StringBuffer('$found device${found == 1 ? '' : 's'} connected')
      ..writeln();
    for (final d in devices) {
      buf.writeln('  $d');
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: {'found': found},
    );
  }
}
