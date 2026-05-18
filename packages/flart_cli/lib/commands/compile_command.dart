import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart compile <target>` — Plan Section 5.4 / 8.1. Subcommands for the
/// canonical dart compile targets.
class CompileCommand extends Command<int> {
  CompileCommand({
    FlartEnv? envOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
  }) {
    for (final target in const [
      'exe',
      'aot-snapshot',
      'jit-snapshot',
      'js',
      'kernel',
    ]) {
      addSubcommand(_CompileTargetCommand(
        target: target,
        envOverride: envOverride,
        stdoutOverride: stdoutOverride,
        stderrOverride: stderrOverride,
      ));
    }
  }

  @override
  String get name => 'compile';

  @override
  String get description =>
      'Run `dart compile <target>` and emit a single success/failure line.';
}

class _CompileTargetCommand extends FilterCommandBase {
  final String target;
  _CompileTargetCommand({
    required this.target,
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => target;

  @override
  String get description => 'Run `dart compile $target` (filtered).';

  @override
  String get invocation => 'flart compile $target [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      CompileFilter(target: target);
}
