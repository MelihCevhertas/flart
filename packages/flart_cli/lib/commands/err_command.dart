import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart err <command...>` — Plan Section 5.5. Runs any command, surfaces
/// only error/marker lines.
class ErrCommand extends FilterCommandBase {
  ErrCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'err';

  @override
  String get description =>
      'Run any command and surface only error/stack-trace lines.';

  @override
  String get invocation => 'flart err <command> [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      ErrFilter();
}
