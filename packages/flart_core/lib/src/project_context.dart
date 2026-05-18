import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Resolved project root for an invocation.
///
/// Used by:
/// - SQLite `invocations.project_path` column (savings grouping).
/// - Project-level config file lookup (`<root>/.flart/config.yaml`).
///
/// Detection walks upward from a start directory looking for `pubspec.yaml`,
/// resolving symlinks once at the start so the canonical path is stored.
@immutable
class ProjectContext {
  /// Canonical absolute path. Either the directory containing `pubspec.yaml`
  /// or the symlink-resolved start directory when no project is found.
  final String root;

  /// `true` when `pubspec.yaml` was located within `maxDepth` parents.
  final bool hasFlutterProject;

  const ProjectContext({required this.root, required this.hasFlutterProject});

  /// Walks upward from [startDir] (defaults to `Directory.current`) up to
  /// [maxDepth] levels looking for `pubspec.yaml`. Falls back to the start
  /// directory when no project is found.
  factory ProjectContext.detect({String? startDir, int maxDepth = 10}) {
    final start = Directory(startDir ?? Directory.current.path);
    String canonicalStart;
    try {
      canonicalStart = start.resolveSymbolicLinksSync();
    } on FileSystemException {
      canonicalStart = p.normalize(start.absolute.path);
    }

    var dir = canonicalStart;
    String? found;
    for (var i = 0; i < maxDepth; i++) {
      if (File(p.join(dir, 'pubspec.yaml')).existsSync()) {
        found = dir;
        break;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }

    return ProjectContext(
      root: found ?? canonicalStart,
      hasFlutterProject: found != null,
    );
  }

  /// True when the resolved project's `pubspec.yaml` depends on Flutter
  /// (`flutter:` under dependencies, `flutter_test:` under dev_dependencies,
  /// or a `flutter:` env constraint). Used by [TestFilter] to pick between
  /// `flutter test` and `dart test`. Reads from disk on each call — cache at
  /// the call site if invoked in a hot loop.
  bool isFlutterPackage() {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final Object? doc;
    try {
      doc = loadYaml(pubspec.readAsStringSync());
    } on YamlException {
      return false;
    }
    if (doc is! Map) return false;
    final deps = doc['dependencies'];
    if (deps is Map && deps.containsKey('flutter')) return true;
    final devDeps = doc['dev_dependencies'];
    if (devDeps is Map && devDeps.containsKey('flutter_test')) return true;
    final env = doc['environment'];
    if (env is Map && env.containsKey('flutter')) return true;
    return false;
  }

  @override
  String toString() =>
      'ProjectContext(root: $root, hasFlutterProject: $hasFlutterProject)';
}
