/// Default configuration map. Source of truth for every config field.
///
/// Keys mirror the YAML structure documented in `flart_PLAN.md` Section 3.2.
/// `null` for path-like fields means "compute the default at the call site"
/// (e.g. `~/.local/share/flart/tee` for `tee.directory`).
Map<String, Object?> defaultConfigMap() => {
      'token_estimation': {
        'chars_per_token': 3.8,
        'estimated_deviation': 0.15,
      },
      'tee': {
        'enabled': true,
        'mode': 'failures',
        'directory': null,
        'max_files': 30,
        'max_file_size_mb': 5,
        'min_size_bytes': 500,
      },
      'filters': {
        'max_failures_shown': 15,
        'max_warnings_shown': 50,
        'truncate_long_messages_at': 300,
        'ultra_compact': false,
      },
      'executor': {
        'timeout_seconds': 60,
        'max_output_bytes': 65536,
        'head_ratio': 0.6,
        'allowed_runtimes': <String>['dart', 'bash', 'python', 'javascript'],
      },
      'savings': {
        'enabled': true,
        'database_path': null,
        'retention_days': 365,
      },
      'log': {
        'level': 'info',
        'file': null,
      },
    };
