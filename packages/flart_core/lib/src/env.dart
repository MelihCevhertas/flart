import 'dart:io';

/// Single source of truth for flart-specific environment variables.
///
/// Construct via [FlartEnv.fromPlatform] in production; pass a custom map
/// in tests so no shell state leaks in.
class FlartEnv {
  final Map<String, String> source;

  const FlartEnv(this.source);

  factory FlartEnv.fromPlatform() => FlartEnv(Platform.environment);

  /// `FLART_NO_SAVINGS=1|true|yes` disables invocation tracking.
  bool get noSavings => _truthy('FLART_NO_SAVINGS');

  /// `FLART_DATA_DIR` overrides the default `~/.local/share/flart/` location.
  /// Returns the raw value (caller resolves `~` if needed).
  String? get dataDir {
    final v = source['FLART_DATA_DIR']?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// `FLART_CONFIG` overrides the default global config path.
  String? get configPath {
    final v = source['FLART_CONFIG']?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// `HOME` (or `USERPROFILE` on Windows) for tilde expansion.
  String? get home => source['HOME'] ?? source['USERPROFILE'];

  bool _truthy(String key) {
    final v = source[key]?.trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }
}
