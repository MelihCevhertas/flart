import 'filter.dart';
import 'filter_result.dart';

/// `flart format` — wraps `dart format`. Plan 5.4.5.
///
/// `dart format` lines look like:
///   - `Formatted <path>`  (default mode, file modified in place)
///   - `Changed <path>`    (`--output=none` dry-run mode)
///   - `Unchanged <path>`  (dry-run mode, no change needed)
///   - `Formatted N files (M changed) in <seconds> seconds.` (summary)
///
/// Filter drops `Unchanged` lines, keeps file paths that did/would change,
/// and preserves the summary. If nothing changed, output collapses to "ok".
class FormatFilter implements CommandFilter {
  @override
  String get name => 'format';

  @override
  String get flartCommand => 'format';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      const ['dart', 'format'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final changedFiles = <String>[];
    String? summary;
    final summaryRegex = RegExp(
      r'^Formatted \d+ files? \((\d+) changed\) in .*$',
    );

    for (final raw in stdout.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      final summaryMatch = summaryRegex.firstMatch(line);
      if (summaryMatch != null) {
        summary = line;
        continue;
      }
      // Default mode prints `Formatted <path>` only for changed files.
      // Dry-run prints `Changed <path>` for would-change, `Unchanged <path>`
      // for no-op. We keep the first two, drop the third.
      if (line.startsWith('Changed ')) {
        changedFiles.add(line.substring('Changed '.length));
      } else if (line.startsWith('Formatted ')) {
        changedFiles.add(line.substring('Formatted '.length));
      }
      // Anything else (Unchanged, blank, vendor spam) is dropped.
    }

    final metadata = <String, Object?>{
      'files_changed': changedFiles.length,
      if (summary != null) 'summary': summary,
    };

    if (changedFiles.isEmpty) {
      return FilterResult(
        output: summary != null ? 'ok ($summary)' : 'ok',
        metadata: metadata,
      );
    }
    final buf = StringBuffer();
    for (final f in changedFiles) {
      buf.writeln('changed: $f');
    }
    if (summary != null) buf.write(summary);
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: metadata,
    );
  }
}
