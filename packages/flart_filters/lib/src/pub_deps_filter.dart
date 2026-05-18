import 'filter.dart';
import 'filter_result.dart';

/// `flart pub deps` — wraps `flutter pub deps`. Plan 5.4.4 (target 80-90%).
///
/// Default: only direct deps. `--tree` keeps the full ASCII tree.
class PubDepsFilter implements CommandFilter {
  final bool isFlutterProject;
  PubDepsFilter({this.isFlutterProject = true});

  @override
  String get name => 'pub_deps';

  @override
  String get flartCommand => 'pub';

  @override
  List<String> baseNativeCommand(List<String> userArgs) => isFlutterProject
      ? const ['flutter', 'pub', 'deps']
      : const ['dart', 'pub', 'deps'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  /// Top-level package line: `├── pkg X.Y.Z` or `└── pkg X.Y.Z`.
  /// Continuation references `pkg...` are excluded.
  static final RegExp _directDepRegex =
      RegExp(r'^[├└]──\s+([a-z][a-z0-9_]*)\s+([0-9].*?)$');

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    if (exitCode != 0) {
      return FilterResult(
        output: 'FAILED: pub deps (exit $exitCode)\n${stderr.trim()}',
        metadata: {'failed': true},
      );
    }

    if (userArgs.contains('--tree')) {
      // Full-tree request: pass through (anti-bloat in runner will pick the
      // shorter of raw vs filter; filter has no value-add at this granularity).
      return FilterResult(
        output: stdout.trimRight(),
        metadata: {'mode': 'tree'},
      );
    }

    final directs = <_DirectDep>[];
    for (final raw in stdout.split('\n')) {
      final m = _directDepRegex.firstMatch(raw);
      if (m == null) continue;
      directs.add(_DirectDep(name: m.group(1)!, version: m.group(2)!.trim()));
    }

    if (directs.isEmpty) {
      // Couldn't find anything; let runner anti-bloat decide.
      return FilterResult(
        output: stdout.trimRight(),
        metadata: {'mode': 'tree', 'fallback': true},
      );
    }

    final buf = StringBuffer('${directs.length} direct dependencies')..writeln();
    for (final d in directs) {
      buf.writeln('  ${d.name} ${d.version}');
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: {'mode': 'direct', 'direct_count': directs.length},
    );
  }
}

class _DirectDep {
  final String name;
  final String version;
  const _DirectDep({required this.name, required this.version});
}
