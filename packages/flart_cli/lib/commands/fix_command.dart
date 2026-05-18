import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart fix` — wraps `dart fix --dry-run` by default; `flart fix --apply`
/// runs the real apply pass. Plan Section 5.2.
class FixCommand extends FilterCommandBase {
  FixCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'fix';

  @override
  String get description =>
      'Run `dart fix` (default --dry-run), surface proposed fixes by file. '
      'Use --apply to rewrite files.';

  @override
  String get invocation => 'flart fix [--apply] [paths...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      FixFilter();
}
