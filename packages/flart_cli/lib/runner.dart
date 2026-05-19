import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';

import 'commands/analyze_command.dart';
import 'commands/build_command.dart';
import 'commands/clean_command.dart';
import 'commands/compile_command.dart';
import 'commands/devices_command.dart';
import 'commands/doctor_command.dart';
import 'commands/err_command.dart';
import 'commands/exec_command.dart';
import 'commands/fix_command.dart';
import 'commands/format_command.dart';
import 'commands/gen_l10n_command.dart';
import 'commands/init_command.dart';
import 'commands/pub_command.dart';
import 'commands/rewrite_command.dart';
import 'commands/savings_command.dart';
import 'commands/task_hook_command.dart';
import 'commands/test_command.dart';
import 'commands/test_wrap_command.dart';
import 'commands/version_command.dart';

/// Builds the top-level [CommandRunner]. Filters, savings, init, and rewrite
/// commands arrive in later phases.
///
/// [envOverride], [stdinOverride], [stdoutOverride] and [stderrOverride] are
/// test seams — production callers pass `null` and the commands use
/// `Platform.environment` / `stdin` / `stdout` / `stderr`.
CommandRunner<int> createRunner({
  FlartEnv? envOverride,
  Stream<List<int>>? stdinOverride,
  IOSink? stdoutOverride,
  IOSink? stderrOverride,
}) {
  final runner = CommandRunner<int>(
    'flart',
    'Token-optimization CLI for Flutter/Dart development with Claude Code.',
  );

  runner.argParser
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable debug-level logging.',
    )
    ..addFlag(
      'quiet',
      abbr: 'q',
      negatable: false,
      help: 'Only print warnings and errors.',
    );

  runner.addCommand(VersionCommand());
  runner.addCommand(ExecCommand(
    envOverride: envOverride,
    stdinOverride: stdinOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(AnalyzeCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(CleanCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(FormatCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(TestCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(PubCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(BuildCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(DoctorCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(FixCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(GenL10nCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(CompileCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(DevicesCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(ErrCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(TestWrapCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(SavingsCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
    stdinOverride: stdinOverride,
  ));
  runner.addCommand(RewriteCommand(
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(TaskHookCommand(
    envOverride: envOverride,
    stdinOverride: stdinOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  ));
  runner.addCommand(InitCommand(
    envOverride: envOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
    stdinOverride: stdinOverride,
  ));
  return runner;
}

/// Entry-point wrapper used by `bin/flart.dart`. Catches usage errors and
/// translates them to flart-internal exit code 100 per Plan Section 8.3.
/// Empty args print top-level help instead of throwing.
Future<int> runFlart(
  List<String> args, {
  FlartEnv? envOverride,
  Stream<List<int>>? stdinOverride,
  IOSink? stdoutOverride,
  IOSink? stderrOverride,
}) async {
  final effective = args.isEmpty ? const ['--help'] : args;
  final runner = createRunner(
    envOverride: envOverride,
    stdinOverride: stdinOverride,
    stdoutOverride: stdoutOverride,
    stderrOverride: stderrOverride,
  );
  try {
    final code = await runner.run(effective);
    return code ?? 0;
  } on UsageException catch (e) {
    final err = stderrOverride ?? stderr;
    err.writeln(e.message);
    err.writeln('');
    err.writeln(e.usage);
    return 100;
  }
}
