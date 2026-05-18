import '../aggregator.dart';

/// Plan Section 6.3 `--csv` export. Single denormalised table covering the
/// common analyses (by-module + by-command + by-project as separate row
/// groups distinguished by a `dimension` column).
class CsvFormatter {
  String render({
    required List<GroupedSavings> byModule,
    required List<GroupedSavings> byCommand,
    required List<GroupedSavings> byProject,
  }) {
    final buf = StringBuffer();
    buf.writeln(
        'dimension,label,invocations,raw_bytes,filtered_bytes,bytes_saved,'
        'est_raw_tokens,est_filtered_tokens,est_tokens_saved,savings_ratio');
    void addRows(String dim, List<GroupedSavings> rows) {
      for (final g in rows) {
        buf.writeln([
          dim,
          _quote(g.label),
          g.invocations,
          g.rawBytes,
          g.filteredBytes,
          g.bytesSaved,
          g.estRawTokens,
          g.estFiltTokens,
          g.tokensSaved,
          g.savingsRatio.toStringAsFixed(4),
        ].join(','));
      }
    }

    addRows('module', byModule);
    addRows('command', byCommand);
    addRows('project', byProject);
    return buf.toString();
  }

  static String _quote(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
