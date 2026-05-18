import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../env.dart';
import 'loader.dart';

/// Thrown when configuration is malformed or contains invalid values.
/// Messages are actionable (include the offending file/field + how to fix).
class FlartConfigException implements Exception {
  final String message;
  const FlartConfigException(this.message);
  @override
  String toString() => 'FlartConfigException: $message';
}

enum TeeMode { failures, always, never }

enum LogLevel { debug, info, warn, error }

@immutable
class TokenEstimationConfig {
  final double charsPerToken;
  final double estimatedDeviation;
  const TokenEstimationConfig({
    required this.charsPerToken,
    required this.estimatedDeviation,
  });
}

@immutable
class TeeConfig {
  final bool enabled;
  final TeeMode mode;

  /// `null` → caller computes default (typically `<dataDir>/tee`).
  final String? directory;
  final int maxFiles;
  final int maxFileSizeMb;
  final int minSizeBytes;
  const TeeConfig({
    required this.enabled,
    required this.mode,
    required this.directory,
    required this.maxFiles,
    required this.maxFileSizeMb,
    required this.minSizeBytes,
  });
}

@immutable
class FilterConfig {
  final int maxFailuresShown;
  final int maxWarningsShown;
  final int truncateLongMessagesAt;
  final bool ultraCompact;
  const FilterConfig({
    required this.maxFailuresShown,
    required this.maxWarningsShown,
    required this.truncateLongMessagesAt,
    required this.ultraCompact,
  });
}

@immutable
class ExecutorConfig {
  final int timeoutSeconds;
  final int maxOutputBytes;
  final double headRatio;
  final List<String> allowedRuntimes;
  const ExecutorConfig({
    required this.timeoutSeconds,
    required this.maxOutputBytes,
    required this.headRatio,
    required this.allowedRuntimes,
  });
}

@immutable
class SavingsConfig {
  final bool enabled;

  /// `null` → caller computes default (typically `<dataDir>/savings.db`).
  final String? databasePath;
  final int retentionDays;
  const SavingsConfig({
    required this.enabled,
    required this.databasePath,
    required this.retentionDays,
  });
}

@immutable
class LogConfig {
  final LogLevel level;

  /// `null` → stderr only.
  final String? file;
  const LogConfig({required this.level, required this.file});
}

@immutable
class Config {
  final TokenEstimationConfig tokenEstimation;
  final TeeConfig tee;
  final FilterConfig filters;
  final ExecutorConfig executor;
  final SavingsConfig savings;
  final LogConfig log;

  const Config({
    required this.tokenEstimation,
    required this.tee,
    required this.filters,
    required this.executor,
    required this.savings,
    required this.log,
  });

  /// Builds [Config] from defaults only.
  factory Config.defaults() => Config.fromMap(ConfigLoader.load());

  /// Loads, merges, and validates a [Config] from optional file paths.
  ///
  /// Paths that don't exist are skipped (use defaults). Paths that exist but
  /// contain invalid YAML throw [FlartConfigException].
  ///
  /// [env] is used for `~` expansion in path-like fields.
  factory Config.load({
    String? globalPath,
    String? projectPath,
    FlartEnv? env,
  }) {
    final raw = ConfigLoader.load(
      globalPath: globalPath,
      projectPath: projectPath,
    );
    return Config.fromMap(raw, env: env);
  }

  /// Builds [Config] from a partial or fully merged map. Defaults are layered
  /// underneath so callers may pass `{'token_estimation': {'chars_per_token': 4}}`
  /// and still get a valid Config. Performs type validation and tilde expansion.
  factory Config.fromMap(Map<String, Object?> map, {FlartEnv? env}) {
    final resolvedEnv = env ?? FlartEnv.fromPlatform();
    final merged = ConfigLoader.mergeWithDefaults(map);
    final te = _asMap(merged, 'token_estimation');
    final tee = _asMap(merged, 'tee');
    final filters = _asMap(merged, 'filters');
    final exec = _asMap(merged, 'executor');
    final savings = _asMap(merged, 'savings');
    final log = _asMap(merged, 'log');

    return Config(
      tokenEstimation: TokenEstimationConfig(
        charsPerToken: _asDouble(te, 'chars_per_token', 'token_estimation'),
        estimatedDeviation:
            _asDouble(te, 'estimated_deviation', 'token_estimation'),
      ),
      tee: TeeConfig(
        enabled: _asBool(tee, 'enabled', 'tee'),
        mode: _asTeeMode(tee, 'mode'),
        directory:
            _expandPath(_asNullableString(tee, 'directory'), resolvedEnv),
        maxFiles: _asInt(tee, 'max_files', 'tee'),
        maxFileSizeMb: _asInt(tee, 'max_file_size_mb', 'tee'),
        minSizeBytes: _asInt(tee, 'min_size_bytes', 'tee'),
      ),
      filters: FilterConfig(
        maxFailuresShown: _asInt(filters, 'max_failures_shown', 'filters'),
        maxWarningsShown: _asInt(filters, 'max_warnings_shown', 'filters'),
        truncateLongMessagesAt:
            _asInt(filters, 'truncate_long_messages_at', 'filters'),
        ultraCompact: _asBool(filters, 'ultra_compact', 'filters'),
      ),
      executor: ExecutorConfig(
        timeoutSeconds: _asInt(exec, 'timeout_seconds', 'executor'),
        maxOutputBytes: _asInt(exec, 'max_output_bytes', 'executor'),
        headRatio: _asDouble(exec, 'head_ratio', 'executor'),
        allowedRuntimes: _asStringList(exec, 'allowed_runtimes', 'executor'),
      ),
      savings: SavingsConfig(
        enabled: _asBool(savings, 'enabled', 'savings'),
        databasePath: _expandPath(
            _asNullableString(savings, 'database_path'), resolvedEnv),
        retentionDays: _asInt(savings, 'retention_days', 'savings'),
      ),
      log: LogConfig(
        level: _asLogLevel(log, 'level'),
        file: _expandPath(_asNullableString(log, 'file'), resolvedEnv),
      ),
    );
  }

  static Map<String, Object?> _asMap(Map<String, Object?> root, String key) {
    final v = root[key];
    if (v == null) return const {};
    if (v is! Map) {
      throw FlartConfigException('$key: expected a map, got ${v.runtimeType}');
    }
    return v.map((k, vv) => MapEntry(k.toString(), vv));
  }

  static double _asDouble(
    Map<String, Object?> m,
    String key,
    String section,
  ) {
    final v = m[key];
    if (v is num) return v.toDouble();
    throw FlartConfigException(
      '$section.$key: expected a number, got ${v.runtimeType}',
    );
  }

  static int _asInt(Map<String, Object?> m, String key, String section) {
    final v = m[key];
    if (v is int) return v;
    if (v is double && v == v.truncateToDouble()) return v.toInt();
    throw FlartConfigException(
      '$section.$key: expected an integer, got ${v.runtimeType}',
    );
  }

  static bool _asBool(Map<String, Object?> m, String key, String section) {
    final v = m[key];
    if (v is bool) return v;
    throw FlartConfigException(
      '$section.$key: expected a boolean, got ${v.runtimeType}',
    );
  }

  static String? _asNullableString(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    throw FlartConfigException(
      '$key: expected a string or null, got ${v.runtimeType}',
    );
  }

  static List<String> _asStringList(
    Map<String, Object?> m,
    String key,
    String section,
  ) {
    final v = m[key];
    if (v is! List) {
      throw FlartConfigException(
        '$section.$key: expected a list, got ${v.runtimeType}',
      );
    }
    return v.map((e) {
      if (e is String) return e;
      throw FlartConfigException(
        '$section.$key: list items must be strings, got ${e.runtimeType}',
      );
    }).toList(growable: false);
  }

  static TeeMode _asTeeMode(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v is String) {
      switch (v) {
        case 'failures':
          return TeeMode.failures;
        case 'always':
          return TeeMode.always;
        case 'never':
          return TeeMode.never;
      }
    }
    throw FlartConfigException(
      "tee.$key: '$v' is not valid. Allowed: failures, always, never.",
    );
  }

  static LogLevel _asLogLevel(Map<String, Object?> m, String key) {
    final v = m[key];
    if (v is String) {
      switch (v) {
        case 'debug':
          return LogLevel.debug;
        case 'info':
          return LogLevel.info;
        case 'warn':
          return LogLevel.warn;
        case 'error':
          return LogLevel.error;
      }
    }
    throw FlartConfigException(
      "log.$key: '$v' is not valid. Allowed: debug, info, warn, error.",
    );
  }

  static String? _expandPath(String? raw, FlartEnv env) {
    if (raw == null) return null;
    if (raw == '~') return env.home;
    if (raw.startsWith('~/')) {
      final home = env.home;
      if (home != null) return p.join(home, raw.substring(2));
    }
    return raw;
  }
}
