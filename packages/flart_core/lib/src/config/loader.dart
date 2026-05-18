import 'dart:io';

import 'package:yaml/yaml.dart';

import 'config.dart' show FlartConfigException;
import 'defaults.dart';

/// Internal loader: reads optional global + project YAML files, deep-merges
/// them onto the defaults map, and returns a plain `Map<String, Object?>`
/// ready to be turned into typed [Config] objects.
class ConfigLoader {
  static Map<String, Object?> load({
    String? globalPath,
    String? projectPath,
  }) {
    final base = defaultConfigMap();
    final layered = <Map<String, Object?>>[
      if (globalPath != null) _readYamlMap(globalPath),
      if (projectPath != null) _readYamlMap(projectPath),
    ];
    var merged = base;
    for (final layer in layered) {
      merged = _deepMerge(merged, layer);
    }
    return merged;
  }

  /// Convenience for tests / callers that already hold a partial map.
  /// Re-merging an already-complete map is a no-op (idempotent).
  static Map<String, Object?> mergeWithDefaults(
    Map<String, Object?> override,
  ) =>
      _deepMerge(defaultConfigMap(), override);

  static Map<String, Object?> _readYamlMap(String path) {
    final file = File(path);
    if (!file.existsSync()) return const {};
    final String content;
    try {
      content = file.readAsStringSync();
    } on FileSystemException catch (e) {
      throw FlartConfigException(
        '$path: cannot read config file — ${e.message}.\n'
        'Check file permissions or remove the file to use defaults.',
      );
    }

    final Object? doc;
    try {
      doc = loadYaml(content);
    } on YamlException catch (e) {
      throw FlartConfigException(
        '$path: invalid YAML — ${e.message}.\n'
        'Fix the syntax error or delete the file to use defaults.',
      );
    }

    if (doc == null) return const {};
    if (doc is! YamlMap) {
      throw FlartConfigException(
        '$path: top-level YAML must be a map, got ${doc.runtimeType}.\n'
        'Wrap your settings under keys like `token_estimation:`, `tee:`, etc.',
      );
    }
    return _yamlToDart(doc) as Map<String, Object?>;
  }

  static Object? _yamlToDart(Object? v) {
    if (v is YamlMap) {
      return <String, Object?>{
        for (final entry in v.nodes.entries)
          entry.key.toString(): _yamlToDart(entry.value.value),
      };
    }
    if (v is YamlList) {
      return v.nodes.map((n) => _yamlToDart(n.value)).toList();
    }
    return v;
  }

  /// Deep merge `override` onto `base`.
  ///
  /// - Maps recurse.
  /// - Lists concatenate, deduplicating by `==` (preserves base order, then
  ///   appends override entries not already present).
  /// - Scalars replace.
  static Map<String, Object?> _deepMerge(
    Map<String, Object?> base,
    Map<String, Object?> override,
  ) {
    final result = <String, Object?>{...base};
    for (final entry in override.entries) {
      final key = entry.key;
      final overrideVal = entry.value;
      final baseVal = result[key];
      if (baseVal is Map<String, Object?> && overrideVal is Map) {
        result[key] = _deepMerge(
          baseVal,
          overrideVal.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else if (baseVal is List && overrideVal is List) {
        final merged = <Object?>[...baseVal];
        for (final item in overrideVal) {
          if (!merged.contains(item)) merged.add(item);
        }
        result[key] = merged;
      } else {
        result[key] = overrideVal;
      }
    }
    return result;
  }
}
