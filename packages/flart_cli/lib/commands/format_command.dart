import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart format` — wraps `dart format` (Plan 5.4.5).
class FormatCommand extends FilterCommandBase {
  FormatCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'format';

  @override
  String get description =>
      'Run `dart format`, drop Unchanged rows, keep changed paths + summary.';

  @override
  String get invocation => 'flart format [paths...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      FormatFilter();
}
