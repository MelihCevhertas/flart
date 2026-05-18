import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'filter.dart';
import 'filter_result.dart';

/// `flart pub get` — wraps `flutter pub get` (or `dart pub get`). Plan 5.4.4.
///
/// Output shapes from real Dart 3.11:
/// ```
/// Resolving dependencies...
/// Downloading packages...
/// + foo 1.2.3                       # added
/// ~ bar 1.0.0 → 1.1.0               # changed
/// - baz (was 0.9.0)                 # removed
/// Changed N dependencies!           # change summary
/// Got dependencies!                 # no-change summary
/// ```
///
/// Compact output:
/// - No changes:  `ok (<N> deps)` where N comes from `pubspec.lock`.
/// - With changes: `ok (<N> deps)` + change list with the original `+`/`~`/`-`
///   markers preserved.
/// - On conflict (non-zero exit, no `Got/Changed` line): the full error block.
class PubGetFilter implements CommandFilter {
  /// Project root used to find `pubspec.lock` for the total-dependency count.
  /// `null` means "skip the count" (helpful in unit tests).
  final String? projectRoot;

  /// Wrap `flutter pub get` vs `dart pub get`. Auto-detected by the CLI.
  final bool isFlutterProject;

  PubGetFilter({this.projectRoot, this.isFlutterProject = true});

  @override
  String get name => 'pub_get';

  @override
  String get flartCommand => 'pub';

  @override
  List<String> baseNativeCommand(List<String> userArgs) => isFlutterProject
      ? const ['flutter', 'pub', 'get']
      : const ['dart', 'pub', 'get'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final lines = stdout.split('\n');
    final changes = <String>[];
    bool sawSuccessSummary = false;
    bool changedSummary = false;
    String? errorBlock;

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('Resolving dependencies') ||
          line.startsWith('Downloading packages')) {
        continue;
      }
      if (line.startsWith('+ ') ||
          line.startsWith('- ') ||
          line.startsWith('~ ') ||
          line.startsWith('> ')) {
        changes.add(line);
        continue;
      }
      if (line.startsWith('Got dependencies')) {
        sawSuccessSummary = true;
        continue;
      }
      if (line.startsWith('Changed ') && line.contains('dependencies')) {
        sawSuccessSummary = true;
        changedSummary = true;
        continue;
      }
      // Anything else on a non-success run is part of the error block.
      if (exitCode != 0 || !sawSuccessSummary) {
        errorBlock = errorBlock == null ? line : '$errorBlock\n$line';
      }
    }

    final depCount = projectRoot != null ? _readDepCount(projectRoot!) : null;
    final metadata = <String, Object?>{
      'changes': changes.length,
      'changed_summary': changedSummary,
      'failed': exitCode != 0,
      if (depCount != null) 'deps_total': depCount,
    };

    if (exitCode != 0) {
      final hint = (errorBlock?.trim().isNotEmpty ?? false)
          ? errorBlock!.trim()
          : (stderr.trim().isEmpty
              ? 'see full output (exit $exitCode)'
              : stderr.trim());
      return FilterResult(
        output: 'FAILED: pub get (exit $exitCode)\n$hint',
        metadata: metadata,
      );
    }

    final headerParts = <String>[];
    if (depCount != null) headerParts.add('$depCount deps');
    if (changes.isNotEmpty) {
      headerParts.add('${changes.length} changed');
    } else {
      headerParts.add('0 changed');
    }
    final header =
        headerParts.isEmpty ? 'ok' : 'ok (${headerParts.join(', ')})';

    if (changes.isEmpty) {
      return FilterResult(output: header, metadata: metadata);
    }
    final buf = StringBuffer(header)..writeln();
    for (final c in changes) {
      buf.writeln('  $c');
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: metadata,
    );
  }

  static int? _readDepCount(String projectRoot) {
    final lock = File(p.join(projectRoot, 'pubspec.lock'));
    if (!lock.existsSync()) return null;
    try {
      final doc = loadYaml(lock.readAsStringSync());
      if (doc is! Map) return null;
      final pkgs = doc['packages'];
      if (pkgs is Map) return pkgs.length;
    } on YamlException {
      // Defensive — corrupted lock file shouldn't crash the filter.
    }
    return null;
  }
}
