import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

class DevicesCommand extends FilterCommandBase {
  DevicesCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'devices';

  @override
  String get description =>
      'Run `flutter devices` and emit a compact connected-device table.';

  @override
  String get invocation => 'flart devices';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      DevicesFilter();
}
