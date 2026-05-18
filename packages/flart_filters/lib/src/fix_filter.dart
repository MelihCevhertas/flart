import 'filter.dart';
import 'filter_result.dart';

/// `flart fix` — wraps `dart fix`. Plan 5.2 + 5.4 (target band 70-95%).
///
/// Two modes, distinguished by whether the user passed `--apply` (Plan):
/// - default → `dart fix --dry-run` (preview)
/// - `flart fix --apply` → `dart fix --apply` (rewrite files)
///
/// Real Dart 3.11 output (dry-run):
/// ```
/// Computing fixes in <pkg> (dry run)...
///
/// 92 proposed fixes in 55 files.
///
/// lib/_tools/artifact_search_helper.dart
///   unnecessary_underscores - 1 fix
///
/// lib/ui/common/collectible_item.dart
///   unnecessary_underscores - 1 fix
/// ...
///
/// To fix an individual diagnostic, run one of:
///   dart fix --apply --code=unnecessary_underscores
///
/// To fix all diagnostics, run:
///   dart fix --apply
/// ```
/// "Nothing to fix!" replaces the body when the project is clean.
///
/// Output strategy — **rule-summary collapse** (v1.6 fix-quality patch):
/// Per-file detail is too verbose on real projects (Wonderous: 92 fixes ×
/// 55 files → only ~6% saved). Instead we aggregate by rule and report
/// `rule_name [N in M files]` sorted by fix count. Agents needing file-
/// level granularity can rerun raw `dart fix --dry-run`. Trade-off
/// captured in Plan v1.6 + 14.5 backlog item #4 (now closed).
class FixFilter implements CommandFilter {
  @override
  String get name => 'fix';

  @override
  String get flartCommand => 'fix';

  @override
  List<String> baseNativeCommand(List<String> userArgs) {
    final wantsApply = userArgs.contains('--apply');
    return wantsApply
        ? const ['dart', 'fix', '--apply']
        : const ['dart', 'fix', '--dry-run'];
  }

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  /// `  rule_name - N fix` (singular) or `  rule_name - N fixes`.
  static final RegExp _ruleLineRegex =
      RegExp(r'^\s+(\w+)\s*-\s*(\d+)\s+fix(?:es)?\s*$');

  /// `N proposed fix(es) in M file(s).` or `N fix(es) made in M file(s).`
  static final RegExp _summaryRegex = RegExp(
    r'^\d+ (?:proposed )?fix(?:es)? (?:proposed in|made in|in) \d+ files?\.$',
  );

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    // {ruleName: {filePath: fixCount}}
    final byRule = <String, Map<String, int>>{};
    String? currentFile;
    String? summaryLine;
    var nothingToFix = false;
    var inHintBlock = false;

    for (final raw in stdout.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('Computing fixes')) continue;
      if (line == 'Nothing to fix!') {
        nothingToFix = true;
        continue;
      }
      if (line.startsWith('To fix ')) {
        inHintBlock = true;
        continue;
      }
      if (inHintBlock) {
        // Drop indented dart-fix --apply suggestions.
        if (line.startsWith('  ')) continue;
        inHintBlock = false;
      }
      if (_summaryRegex.hasMatch(line)) {
        summaryLine = line;
        continue;
      }
      // File line: no leading whitespace, ends in `.dart`.
      if (!line.startsWith(' ') && line.endsWith('.dart')) {
        currentFile = line;
        continue;
      }
      // Rule line under a file.
      final ruleMatch = _ruleLineRegex.firstMatch(line);
      if (ruleMatch != null && currentFile != null) {
        final rule = ruleMatch.group(1)!;
        final count = int.parse(ruleMatch.group(2)!);
        final bucket = byRule.putIfAbsent(rule, () => <String, int>{});
        bucket[currentFile] = (bucket[currentFile] ?? 0) + count;
      }
    }

    final wasApply = userArgs.contains('--apply');
    final totalFiles =
        byRule.values.expand((m) => m.keys).toSet().length;
    final totalFixes = byRule.values
        .expand((m) => m.values)
        .fold<int>(0, (s, n) => s + n);

    final metadata = <String, Object?>{
      'mode': wasApply ? 'apply' : 'dry_run',
      'files': totalFiles,
      'rules': byRule.length,
      'fixes': totalFixes,
      'nothing_to_fix': nothingToFix,
    };

    if (nothingToFix || byRule.isEmpty) {
      return FilterResult(output: 'no fixes needed', metadata: metadata);
    }

    final buf = StringBuffer();
    if (summaryLine != null) {
      buf.writeln(summaryLine);
    } else {
      final verb = wasApply ? 'fixes applied' : 'proposed fixes';
      buf.writeln(
        '$totalFixes $verb in $totalFiles file${totalFiles == 1 ? '' : 's'}.',
      );
    }
    // Sort: most fixes first, tie-break by rule name.
    final sortedRules = byRule.entries.toList()
      ..sort((a, b) {
        final aTotal = a.value.values.fold<int>(0, (s, n) => s + n);
        final bTotal = b.value.values.fold<int>(0, (s, n) => s + n);
        final byCount = bTotal.compareTo(aTotal);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    for (final entry in sortedRules) {
      final ruleTotal =
          entry.value.values.fold<int>(0, (s, n) => s + n);
      final fileCount = entry.value.length;
      buf.writeln(
        '  ${entry.key} [$ruleTotal in $fileCount file${fileCount == 1 ? '' : 's'}]',
      );
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: metadata,
    );
  }
}
