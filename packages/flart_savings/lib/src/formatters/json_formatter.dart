import 'dart:convert';

import '../aggregator.dart';

/// Plan Section 6.3 `--json` output. Stable, machine-readable schema; the
/// CLI prints `jsonEncode(...)` directly so callers can `jq` against it.
class JsonFormatter {
  String render({
    required SavingsSummary summary,
    required List<GroupedSavings> byModule,
    required List<GroupedSavings> byProject,
    required List<GroupedSavings> topCommands,
    DateTime? generatedAt,
  }) {
    final doc = <String, Object?>{
      'report_generated_at':
          (generatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      'since': summary.since?.toIso8601String(),
      'until': summary.until?.toIso8601String(),
      'summary': {
        'invocations': summary.invocations,
        'raw_bytes': summary.rawBytes,
        'filtered_bytes': summary.filteredBytes,
        'bytes_saved': summary.bytesSaved,
        'savings_ratio': summary.savingsRatio,
        'est_raw_tokens': summary.estRawTokens,
        'est_filtered_tokens': summary.estFiltTokens,
        'est_tokens_saved': summary.tokensSaved,
        'token_savings_ratio': summary.tokenSavingsRatio,
      },
      'by_module': byModule.map(_groupToJson).toList(),
      'by_project': byProject.map(_groupToJson).toList(),
      'top_commands': topCommands.map(_groupToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  Map<String, Object?> _groupToJson(GroupedSavings g) => {
        'label': g.label,
        'invocations': g.invocations,
        'raw_bytes': g.rawBytes,
        'filtered_bytes': g.filteredBytes,
        'bytes_saved': g.bytesSaved,
        'est_raw_tokens': g.estRawTokens,
        'est_filtered_tokens': g.estFiltTokens,
        'est_tokens_saved': g.tokensSaved,
        'savings_ratio': g.savingsRatio,
      };
}
