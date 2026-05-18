import 'dart:convert';

import 'filter.dart';
import 'filter_result.dart';

/// `flart pub outdated` — wraps `flutter pub outdated --json`. Plan 5.4.4
/// (target band 60-75%, lower than other pubs because outdated output is
/// already semi-tabular).
///
/// JSON is the stable parse target. If the user passes `--no-json` or a
/// flag that disables JSON, the filter falls back to text-mode parsing.
class PubOutdatedFilter implements CommandFilter {
  final bool isFlutterProject;

  PubOutdatedFilter({this.isFlutterProject = true});

  @override
  String get name => 'pub_outdated';

  @override
  String get flartCommand => 'pub';

  @override
  List<String> baseNativeCommand(List<String> userArgs) {
    final base = isFlutterProject
        ? ['flutter', 'pub', 'outdated']
        : ['dart', 'pub', 'outdated'];
    // Always request JSON unless the user opted out explicitly.
    if (!userArgs.contains('--no-json')) {
      base.add('--json');
    }
    return base;
  }

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    if (exitCode != 0) {
      return FilterResult(
        output: 'FAILED: pub outdated (exit $exitCode)\n${stderr.trim()}',
        metadata: {'failed': true},
      );
    }

    final stale = <_OutdatedPkg>[];
    final trimmed = stdout.trim();
    if (trimmed.startsWith('{')) {
      stale.addAll(_parseJson(trimmed));
    } else {
      stale.addAll(_parseText(trimmed));
    }

    if (stale.isEmpty) {
      return const FilterResult(
        output: 'all dependencies are up to date',
        metadata: {'failed': false, 'outdated': 0},
      );
    }

    final buf = StringBuffer('${stale.length} package(s) outdated')..writeln();
    for (final p in stale) {
      buf.writeln(
        '  ${p.name} (${p.kind}): ${p.current} → ${p.latest}',
      );
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: {'failed': false, 'outdated': stale.length},
    );
  }

  static List<_OutdatedPkg> _parseJson(String body) {
    try {
      final doc = jsonDecode(body);
      if (doc is! Map) return const [];
      final pkgs = doc['packages'];
      if (pkgs is! List) return const [];
      final out = <_OutdatedPkg>[];
      for (final p in pkgs) {
        if (p is! Map) continue;
        final current = (p['current'] is Map)
            ? (p['current'] as Map)['version'] as String?
            : null;
        final latest = (p['latest'] is Map)
            ? (p['latest'] as Map)['version'] as String?
            : null;
        if (current == null || latest == null) continue;
        if (current == latest) continue;
        out.add(_OutdatedPkg(
          name: (p['package'] as String?) ?? '?',
          kind: (p['kind'] as String?) ?? 'unknown',
          current: current,
          latest: latest,
        ));
      }
      return out;
    } on FormatException {
      return const [];
    }
  }

  /// Text mode: rows look like `name  *X.Y.Z  *X.Y.Z  *X.Y.Z  A.B.C`.
  /// We slice the leading word + the leftmost/rightmost version columns.
  static List<_OutdatedPkg> _parseText(String body) {
    final out = <_OutdatedPkg>[];
    String? currentKind;
    final kindHeader = RegExp(r'^([a-z_ ]+):\s*(all up-to-date\.?)?$');
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty || line.startsWith('Showing ') || line.startsWith('[*]')) {
        continue;
      }
      final h = kindHeader.firstMatch(line);
      if (h != null) {
        currentKind = h.group(1)!.trim().replaceAll(' ', '_');
        continue;
      }
      // Data row — at least 4 whitespace-separated fields.
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      final name = parts.first;
      final current = parts[1].replaceFirst('*', '');
      final latest = parts.last.replaceFirst('*', '');
      if (current == latest) continue;
      out.add(_OutdatedPkg(
        name: name,
        kind: currentKind ?? 'unknown',
        current: current,
        latest: latest,
      ));
    }
    return out;
  }
}

class _OutdatedPkg {
  final String name;
  final String kind;
  final String current;
  final String latest;
  const _OutdatedPkg({
    required this.name,
    required this.kind,
    required this.current,
    required this.latest,
  });
}
