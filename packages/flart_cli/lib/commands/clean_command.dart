import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart clean` — wraps `flutter clean` (Plan 5.2, 95%+ savings target).
class CleanCommand extends FilterCommandBase {
  CleanCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'clean';

  @override
  String get description =>
      'Run `flutter clean` and collapse the output to "ok" (or a short '
      'failure hint).';

  @override
  String get invocation => 'flart clean';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      CleanFilter();
}
