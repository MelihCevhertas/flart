import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flart_hooks/flart_hooks.dart';

/// `flart rewrite <command>` — Plan Section 7.4. Pure CLI shell around
/// [CommandRewriter]; the Bash hook pipes the agent's command in and uses
/// the printed output as the rewritten form.
///
/// Exit code protocol (Plan v1.8 A reaffirmed):
/// - exit 0 + different string → rewrite applied (hook auto-allows).
/// - exit 0 + identical string → no change (hook passthrough).
/// - exit 1 → invalid input (e.g. empty); hook passthrough.
class RewriteCommand extends Command<int> {
  final IOSink? _stdoutOverride;
  final IOSink? _stderrOverride;

  RewriteCommand({IOSink? stdoutOverride, IOSink? stderrOverride})
      : _stdoutOverride = stdoutOverride,
        _stderrOverride = stderrOverride;

  /// Keep all flags as positional args so things like `--release` round-trip
  /// through `flart rewrite "flutter build apk --release"` cleanly.
  @override
  ArgParser get argParser => ArgParser.allowAnything();

  @override
  String get name => 'rewrite';

  @override
  String get description =>
      'Rewrite a bash command to its flart equivalent (used by the PreToolUse hook).';

  @override
  String get invocation => 'flart rewrite "<bash command>"';

  @override
  Future<int> run() async {
    final out = _stdoutOverride ?? stdout;
    final err = _stderrOverride ?? stderr;
    final input = argResults?.arguments.join(' ').trim() ?? '';
    if (input.isEmpty) {
      err.writeln('flart rewrite: missing command. '
          'Usage: flart rewrite "<bash command>"');
      return 1;
    }
    out.writeln(CommandRewriter().rewrite(input));
    return 0;
  }
}
