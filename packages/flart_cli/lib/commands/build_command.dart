import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart build <target>` — Plan Section 5.4.3 / 8.1. Mounts apk/web/ipa as
/// subcommands so `flart build apk lib/` parses the way `flutter build apk
/// lib/` would.
class BuildCommand extends Command<int> {
  BuildCommand({
    FlartEnv? envOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
  }) {
    for (final target in const ['apk', 'web', 'ipa']) {
      addSubcommand(_BuildTargetCommand(
        target: target,
        envOverride: envOverride,
        stdoutOverride: stdoutOverride,
        stderrOverride: stderrOverride,
      ));
    }
  }

  @override
  String get name => 'build';

  @override
  String get description =>
      'Run `flutter build <target>` and emit a compact success/failure summary.';
}

class _BuildTargetCommand extends FilterCommandBase {
  final String target;

  _BuildTargetCommand({
    required this.target,
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => target;

  @override
  String get description => 'Run `flutter build $target` (filtered).';

  @override
  String get invocation => 'flart build $target [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      BuildFilter(
        target: target,
        truncateMessagesAt: config.filters.truncateLongMessagesAt,
      );
}
