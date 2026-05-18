import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart test` — wraps `flutter test --reporter=json` (Plan 5.4.2).
class TestCommand extends FilterCommandBase {
  TestCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'test';

  @override
  String get description =>
      'Run `flutter test`, surface failures only with one stack frame each.';

  @override
  String get invocation => 'flart test [paths...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) {
    // Auto-detect runtime per Plan v1.5: Flutter pubspec → `flutter test`,
    // pure-Dart pubspec → `dart test`. JSON event format is identical, so
    // the parser doesn't change.
    return TestFilter(
      isFlutterProject: project.isFlutterPackage(),
      truncateMessagesAt: config.filters.truncateLongMessagesAt,
    );
  }
}
