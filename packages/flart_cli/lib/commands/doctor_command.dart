import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart doctor` — wraps `flutter doctor` (Plan 5.4.7).
class DoctorCommand extends FilterCommandBase {
  DoctorCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Run `flutter doctor`, collapse healthy categories, keep issues in detail.';

  @override
  String get invocation => 'flart doctor';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      DoctorFilter();
}
