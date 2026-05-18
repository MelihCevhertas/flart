import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';

import '_filter_command_base.dart';

/// `flart pub <subcommand>` — Plan Section 8.1. Exposes `get`, `upgrade`,
/// `outdated`, `deps`.
class PubCommand extends Command<int> {
  PubCommand({
    FlartEnv? envOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
  }) {
    addSubcommand(_PubGetCommand(
      envOverride: envOverride,
      stdoutOverride: stdoutOverride,
      stderrOverride: stderrOverride,
    ));
    addSubcommand(_PubUpgradeCommand(
      envOverride: envOverride,
      stdoutOverride: stdoutOverride,
      stderrOverride: stderrOverride,
    ));
    addSubcommand(_PubOutdatedCommand(
      envOverride: envOverride,
      stdoutOverride: stdoutOverride,
      stderrOverride: stderrOverride,
    ));
    addSubcommand(_PubDepsCommand(
      envOverride: envOverride,
      stdoutOverride: stdoutOverride,
      stderrOverride: stderrOverride,
    ));
  }

  @override
  String get name => 'pub';

  @override
  String get description =>
      'Filtered wrappers around `flutter pub` / `dart pub` subcommands.';
}

class _PubGetCommand extends FilterCommandBase {
  _PubGetCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'get';

  @override
  String get description =>
      'Run `pub get` and collapse the output to a compact deps summary.';

  @override
  String get invocation => 'flart pub get [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) => PubGetFilter(
        projectRoot: project.root,
        isFlutterProject: project.isFlutterPackage(),
      );
}

class _PubUpgradeCommand extends FilterCommandBase {
  _PubUpgradeCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'upgrade';

  @override
  String get description =>
      'Run `pub upgrade` and report only the packages that changed.';

  @override
  String get invocation => 'flart pub upgrade [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      PubUpgradeFilter(isFlutterProject: project.isFlutterPackage());
}

class _PubOutdatedCommand extends FilterCommandBase {
  _PubOutdatedCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'outdated';

  @override
  String get description =>
      'Run `pub outdated --json` and list only packages that have a newer version.';

  @override
  String get invocation => 'flart pub outdated [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      PubOutdatedFilter(isFlutterProject: project.isFlutterPackage());
}

class _PubDepsCommand extends FilterCommandBase {
  _PubDepsCommand({
    super.envOverride,
    super.stdoutOverride,
    super.stderrOverride,
  });

  @override
  String get name => 'deps';

  @override
  String get description =>
      'Run `pub deps`, list only direct dependencies (use --tree for the full tree).';

  @override
  String get invocation => 'flart pub deps [--tree] [args...]';

  @override
  CommandFilter buildFilter(ProjectContext project, Config config) =>
      PubDepsFilter(isFlutterProject: project.isFlutterPackage());
}
