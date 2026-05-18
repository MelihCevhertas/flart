import 'dart:io';

/// Canonical runtimes the executor knows how to launch. Plan Section 4.2.
enum Runtime {
  dart,
  bash,
  python,
  node;

  static const Map<String, Runtime> _aliases = {
    'dart': Runtime.dart,
    'bash': Runtime.bash,
    'sh': Runtime.bash,
    'python': Runtime.python,
    'python3': Runtime.python,
    'node': Runtime.node,
    'js': Runtime.node,
    'javascript': Runtime.node,
  };

  /// Maps user input (including aliases like `sh`, `python3`, `js`,
  /// `javascript`) to a canonical [Runtime]. Case-insensitive, trims
  /// whitespace.
  ///
  /// Throws [ArgumentError] for unknown runtimes with an actionable message
  /// listing all supported aliases.
  static Runtime resolve(String input) {
    final lower = input.toLowerCase().trim();
    final hit = _aliases[lower];
    if (hit == null) {
      throw ArgumentError(
        "Unknown runtime '$input'. Supported: dart, bash (or sh), "
        'python (or python3), node (or javascript).',
      );
    }
    return hit;
  }

  /// File extension used when writing the script to disk before launch.
  String get scriptExtension {
    switch (this) {
      case Runtime.dart:
        return 'dart';
      case Runtime.bash:
        return 'sh';
      case Runtime.python:
        return 'py';
      case Runtime.node:
        return 'js';
    }
  }
}

/// Resolves a [Runtime] to a concrete executable name available on PATH.
///
/// For [Runtime.python] tries `python3` first, falls back to `python` — modern
/// distributions have removed the unversioned `python` symlink (Plan 4.2).
///
/// The [exists] dependency is injectable so unit tests don't have to actually
/// shell out to `which`.
class RuntimeDetector {
  final Future<bool> Function(String exe) _exists;

  RuntimeDetector({Future<bool> Function(String exe)? exists})
      : _exists = exists ?? _defaultExists;

  /// Returns the executable name (e.g. `python3`) for [runtime], or `null`
  /// when none of the candidates resolve on PATH.
  Future<String?> detect(Runtime runtime) async {
    for (final exe in candidates(runtime)) {
      if (await _exists(exe)) return exe;
    }
    return null;
  }

  /// Ordered list of executable names to try for [runtime].
  static List<String> candidates(Runtime r) {
    switch (r) {
      case Runtime.dart:
        return const ['dart'];
      case Runtime.bash:
        return const ['bash'];
      case Runtime.python:
        return const ['python3', 'python'];
      case Runtime.node:
        return const ['node'];
    }
  }

  static Future<bool> _defaultExists(String exe) async {
    try {
      final result = await Process.run('which', [exe]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
