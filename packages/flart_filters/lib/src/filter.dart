import 'filter_result.dart';

/// Pure transformation contract for command output filters. Implementations
/// receive captured stdout/stderr and produce a compact [FilterResult]; they
/// MUST be free of side effects (no process spawning, file I/O, or DB writes
/// — those are the `FilterRunner`'s concern, which lives in `flart_cli`).
///
/// See Plan Section 5.3 for the architecture rationale.
abstract class CommandFilter {
  /// Filter's unique identifier (e.g. `analyze`, `test`, `pub_get`).
  String get name;

  /// The `flart` subcommand this filter is wired to. Used as the `command`
  /// column in the savings DB.
  String get flartCommand;

  /// Native command + flags to spawn (e.g.
  /// `['dart', 'analyze', '--format=machine']`). User-supplied positional
  /// args are appended by the runner; do NOT include them here.
  List<String> baseNativeCommand(List<String> userArgs);

  /// Environment variables to set when invoking the native command. Default
  /// is none.
  Map<String, String> environment(List<String> userArgs) => const {};

  /// Pure transformation: captured stdout + stderr + exit code → compact
  /// output. No I/O, no spawning. Used directly in unit tests with fixture
  /// data.
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  });
}
