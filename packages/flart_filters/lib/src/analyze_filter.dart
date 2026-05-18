import 'dart:io';

import 'package:path/path.dart' as p;

import 'filter.dart';
import 'filter_result.dart';
import 'filter_utils.dart';

/// `flart analyze` — wraps `dart analyze --format=machine`. Plan Section 5.4.1.
///
/// Output strategy:
/// - ERROR severity: shown in full (file path + line:col + code + message).
/// - WARNING severity: grouped by rule code with count + distinct file count.
/// - INFO severity: collapsed to a single suppressed-count line.
/// - Generated files (`.g.dart`, `.freezed.dart`, `.gr.dart`, `.config.dart`):
///   bucketed separately with a count line.
///
/// Codes are emitted lowercase (`unused_local_variable`) for readability;
/// `dart analyze --format=machine` emits them uppercase.
class AnalyzeFilter implements CommandFilter {
  /// Resolves absolute paths to a path relative to this directory in the
  /// rendered output. Defaults to `Directory.current` at filter-construction
  /// time; tests can pass a fixture-friendly value.
  final String relativeTo;

  /// Per-issue message length cap. Plan Section 3.2 default 300; pass 0 to
  /// disable. Sourced from `config.filters.truncate_long_messages_at` by the
  /// CLI.
  final int truncateMessagesAt;

  AnalyzeFilter({String? relativeTo, this.truncateMessagesAt = 300})
      : relativeTo = relativeTo ?? Directory.current.path;

  @override
  String get name => 'analyze';

  @override
  String get flartCommand => 'analyze';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      const ['dart', 'analyze', '--format=machine'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final issues = _parseIssues(stdout);
    final realIssues = <_Issue>[];
    final generatedIssues = <_Issue>[];
    for (final i in issues) {
      if (_isGenerated(i.file)) {
        generatedIssues.add(i);
      } else {
        realIssues.add(i);
      }
    }

    final errors =
        realIssues.where((i) => i.severity == 'ERROR').toList(growable: false);
    final warnings = realIssues
        .where((i) => i.severity == 'WARNING')
        .toList(growable: false);
    final infos =
        realIssues.where((i) => i.severity == 'INFO').toList(growable: false);

    final warningsByCode = <String, List<_Issue>>{};
    for (final w in warnings) {
      warningsByCode.putIfAbsent(w.code, () => []).add(w);
    }

    final metadata = <String, Object?>{
      'errors': errors.length,
      'warnings_unique': warningsByCode.length,
      'warnings_total': warnings.length,
      'infos_suppressed': infos.length,
      if (generatedIssues.isNotEmpty)
        'generated_suppressed': generatedIssues.length,
    };

    if (issues.isEmpty) {
      return const FilterResult(
        output: 'No issues.',
        metadata: {
          'errors': 0,
          'warnings_unique': 0,
          'warnings_total': 0,
          'infos_suppressed': 0,
        },
      );
    }

    final buf = StringBuffer();

    if (errors.isNotEmpty) {
      buf.writeln('ERRORS (${errors.length}):');
      final byFile = <String, List<_Issue>>{};
      for (final e in errors) {
        byFile.putIfAbsent(e.file, () => []).add(e);
      }
      for (final entry in byFile.entries) {
        buf.writeln('  ${_displayPath(entry.key)}:');
        for (final i in entry.value) {
          final message = FilterUtils.truncateMessage(
            i.message,
            truncateMessagesAt,
          );
          buf.writeln(
            '    L${i.line}:${i.col}  ${_displayCode(i.code)}: $message',
          );
        }
      }
    }

    if (warnings.isNotEmpty) {
      if (errors.isNotEmpty) buf.writeln();
      buf.writeln(
        'WARNINGS (${warningsByCode.length} unique, '
        '${warnings.length} total):',
      );
      // Sort: most occurrences first; tie-break alphabetically.
      final entries = warningsByCode.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.length.compareTo(a.value.length);
          return byCount != 0 ? byCount : a.key.compareTo(b.key);
        });
      for (final entry in entries) {
        final fileCount = entry.value.map((i) => i.file).toSet().length;
        buf.writeln(
          '  ${_displayCode(entry.key)} [${entry.value.length}]: in '
          '$fileCount file${fileCount == 1 ? '' : 's'}',
        );
      }
    }

    if (infos.isNotEmpty) {
      if (errors.isNotEmpty || warnings.isNotEmpty) buf.writeln();
      buf.writeln(
        'INFO: ${infos.length} hint${infos.length == 1 ? '' : 's'} suppressed '
        '(use -v to show)',
      );
    }

    if (generatedIssues.isNotEmpty) {
      if (errors.isNotEmpty || warnings.isNotEmpty || infos.isNotEmpty) {
        buf.writeln();
      }
      buf.writeln(
        'Generated files: ${generatedIssues.length} issue'
        '${generatedIssues.length == 1 ? '' : 's'} suppressed '
        '(.g.dart, .freezed.dart, .gr.dart, .config.dart)',
      );
    }

    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: metadata,
    );
  }

  List<_Issue> _parseIssues(String stdout) {
    final issues = <_Issue>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('|');
      if (parts.length < 8) continue;
      final lineNo = int.tryParse(parts[4]);
      final col = int.tryParse(parts[5]);
      final length = int.tryParse(parts[6]);
      if (lineNo == null || col == null || length == null) continue;
      issues.add(_Issue(
        severity: parts[0],
        type: parts[1],
        code: parts[2],
        file: parts[3],
        line: lineNo,
        col: col,
        length: length,
        // Message can contain pipes (rare); rejoin tail with `|`.
        message: parts.skip(7).join('|'),
      ));
    }
    return issues;
  }

  static const _generatedExtensions = <String>[
    '.g.dart',
    '.freezed.dart',
    '.gr.dart',
    '.config.dart',
  ];

  bool _isGenerated(String path) {
    for (final ext in _generatedExtensions) {
      if (path.endsWith(ext)) return true;
    }
    return false;
  }

  String _displayPath(String absPath) {
    // Strip cwd prefix when possible for short relative paths. Fixture paths
    // (like `<LAB>/lib/foo.dart`) won't match cwd and are shown verbatim.
    if (!p.isAbsolute(absPath)) return absPath;
    if (p.isWithin(relativeTo, absPath)) {
      return p.relative(absPath, from: relativeTo);
    }
    return absPath;
  }

  /// `INVALID_ASSIGNMENT` → `invalid_assignment` for human-friendly display.
  String _displayCode(String code) => code.toLowerCase();
}

class _Issue {
  final String severity;
  final String type;
  final String code;
  final String file;
  final int line;
  final int col;
  final int length;
  final String message;

  const _Issue({
    required this.severity,
    required this.type,
    required this.code,
    required this.file,
    required this.line,
    required this.col,
    required this.length,
    required this.message,
  });
}
