import 'filter.dart';
import 'filter_result.dart';

/// `flart doctor` — wraps `flutter doctor`. Plan 5.4.7.
///
/// Output rule (Plan):
/// - `[✓]` categories: collapsed to a one-line note.
/// - `[!]` partial categories: header + sub-bullets kept (the bullets contain
///   the actionable instructions).
/// - `[✗]` missing categories: full detail kept.
class DoctorFilter implements CommandFilter {
  @override
  String get name => 'doctor';

  @override
  String get flartCommand => 'doctor';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      const ['flutter', 'doctor'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  /// Header line: `[✓] Flutter (Channel ...)`, `[!] Android toolchain ...`,
  /// `[✗] Xcode ...`. Captures status and label separately.
  static final RegExp _headerRegex = RegExp(r'^\[([✓!✗])\]\s+(.+)$');

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final lines = stdout.split('\n');
    final sections = <_DoctorSection>[];
    _DoctorSection? current;
    String? trailingSummary;

    for (final raw in lines) {
      final line = raw.trimRight();
      final match = _headerRegex.firstMatch(line);
      if (match != null) {
        if (current != null) sections.add(current);
        current = _DoctorSection(
          status: match.group(1)!,
          label: match.group(2)!,
        );
        continue;
      }
      if (line.startsWith('!') || line.startsWith('Doctor found')) {
        // "! Doctor found issues in N category." final summary line.
        trailingSummary = line;
        continue;
      }
      if (line.isEmpty) continue;
      // Sub-bullet content (lines like "    ! Some Android licenses..." or
      // "    • Xcode 15.4 found but xcodebuild not in PATH"). Trim leading
      // whitespace; we re-indent in render.
      if (current != null) current.bullets.add(line.trimLeft());
    }
    if (current != null) sections.add(current);

    int ok = 0, partial = 0, missing = 0;
    for (final s in sections) {
      switch (s.status) {
        case '✓':
          ok++;
        case '!':
          partial++;
        case '✗':
          missing++;
      }
    }

    final buf = StringBuffer();

    final partials = sections.where((s) => s.status == '!').toList();
    final missings = sections.where((s) => s.status == '✗').toList();

    for (final s in missings) {
      buf.writeln('✗ ${s.label}');
      for (final b in s.bullets) {
        buf.writeln('  $b');
      }
    }
    if (missings.isNotEmpty && partials.isNotEmpty) buf.writeln();
    for (final s in partials) {
      buf.writeln('! ${s.label}');
      for (final b in s.bullets) {
        buf.writeln('  $b');
      }
    }

    if (missings.isEmpty && partials.isEmpty) {
      buf.writeln('✓ All $ok categories healthy.');
    } else {
      if (buf.isNotEmpty) buf.writeln();
      buf.write('✓ $ok ok');
      if (partial > 0) buf.write(' / ! $partial partial');
      if (missing > 0) buf.write(' / ✗ $missing missing');
      if (trailingSummary != null) {
        buf.writeln();
        buf.write(trailingSummary);
      }
    }

    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: {
        'ok': ok,
        'partial': partial,
        'missing': missing,
      },
    );
  }
}

class _DoctorSection {
  final String status;
  final String label;
  final List<String> bullets = [];
  _DoctorSection({required this.status, required this.label});
}
