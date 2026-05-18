import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart analyze` — wraps `dart analyze --format=machine` (Plan 5.4.1).
class AnalyzeCommand extends FilterCommandBase {
  AnalyzeCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'analyze';

  @override
  String get description =>
      'Run `dart analyze` and emit a compact, grouped summary.';

  @override
  String get invocation => 'flart analyze [paths...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      AnalyzeFilter(
        relativeTo: project.root,
        truncateMessagesAt: config.filters.truncateLongMessagesAt,
      );
}
