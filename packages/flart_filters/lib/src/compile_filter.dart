import 'filter.dart';
import 'filter_result.dart';

/// `flart compile <target>` — wraps `dart compile <target>`. Plan 5.4 final
/// row (compile exe / aot-snapshot / js).
///
/// Modern Dart compile output is very compact: `Generated: <path>` on success,
/// or a brief error block on failure.
class CompileFilter implements CommandFilter {
  /// `exe` | `aot-snapshot` | `jit-snapshot` | `js` | `kernel`. Set by CLI.
  final String target;

  CompileFilter({required this.target});

  @override
  String get name => 'compile_$target';

  @override
  String get flartCommand => 'compile';

  @override
  List<String> baseNativeCommand(List<String> userArgs) =>
      ['dart', 'compile', target];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  static final RegExp _generatedRegex =
      RegExp(r'^Generated:?\s*(.+)$', multiLine: true);

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    if (exitCode == 0) {
      final m = _generatedRegex.firstMatch(stdout);
      final outputPath = m?.group(1)?.trim();
      final body =
          outputPath != null ? '✓ Compiled $target → $outputPath' : '✓ ok';
      return FilterResult(
        output: body,
        metadata: {
          'target': target,
          'success': true,
          if (outputPath != null) 'output_path': outputPath,
        },
      );
    }
    final body = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
    return FilterResult(
      output: '✗ Compile failed ($target, exit $exitCode)\n'
          '${body.split('\n').take(8).join('\n')}',
      metadata: {'target': target, 'success': false},
    );
  }
}
