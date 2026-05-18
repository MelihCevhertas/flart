import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

class GenL10nCommand extends FilterCommandBase {
  GenL10nCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'gen-l10n';

  @override
  String get description =>
      'Run `flutter gen-l10n` and emit a compact generated-path + untranslated-key summary.';

  @override
  String get invocation => 'flart gen-l10n';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      GenL10nFilter();
}
