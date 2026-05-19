import 'package:args/command_runner.dart';

/// Build-time-stamped version metadata. Wire up at compile time via:
///
/// ```
/// dart compile exe ... \
///   --define=FLART_VERSION=0.3.0 \
///   --define=GIT_SHA=$(git rev-parse --short HEAD) \
///   --define=BUILD_DATE=$(date -u +%Y-%m-%d)
/// ```
///
/// A dev build (no `--define` flags) shows just `flart 0.3.0-dev`; a CI
/// release build adds the commit/date trailer. The binary never shells out
/// to `git` at runtime — values are baked into the executable.
const String flartVersion =
    String.fromEnvironment('FLART_VERSION', defaultValue: '0.3.0-dev');
const String _gitSha =
    String.fromEnvironment('GIT_SHA', defaultValue: 'unknown');
const String _buildDate =
    String.fromEnvironment('BUILD_DATE', defaultValue: 'unknown');

/// Rendered `flart version` line. Exposed for testing; production callers
/// use [VersionCommand].
String renderVersionLine() {
  if (_gitSha == 'unknown' && _buildDate == 'unknown') {
    return 'flart $flartVersion';
  }
  return 'flart $flartVersion (commit $_gitSha, built $_buildDate)';
}

class VersionCommand extends Command<int> {
  @override
  String get name => 'version';

  @override
  String get description => 'Print the flart version.';

  @override
  int run() {
    print(renderVersionLine());
    return 0;
  }
}
