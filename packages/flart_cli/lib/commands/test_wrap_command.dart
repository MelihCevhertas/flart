import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart test-wrap <command...>` — Plan Section 5.5. Generic test summary
/// extractor for runners without a JSON reporter.
class TestWrapCommand extends FilterCommandBase {
  TestWrapCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'test-wrap';

  @override
  String get description =>
      'Wrap any test runner, surface only counts + failing test markers.';

  @override
  String get invocation => 'flart test-wrap <command> [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      TestWrapFilter();
}
