import '../aggregator.dart';

/// Plan Section 6.3 `--graph`. Renders a single-row Unicode block bar chart
/// of `tokensSaved` per day. Higher resolution multi-row charts can come
/// in v1.1 if there's appetite (Plan 14.5 v1.1+ list).
class GraphFormatter {
  static const _blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];

  String render(List<DailyBucket> buckets) {
    if (buckets.isEmpty) {
      return 'No data to graph.\n';
    }
    final maxValue = buckets
        .map((b) => b.tokensSaved)
        .fold<int>(0, (m, v) => v > m ? v : m);
    if (maxValue <= 0) {
      return 'No tokens saved in this window.\n';
    }
    final bars = StringBuffer();
    for (final b in buckets) {
      bars.write(_bar(b.tokensSaved, maxValue));
    }

    final start = buckets.first.day;
    final end = buckets.last.day;
    final peak = buckets.reduce(
        (a, b) => b.tokensSaved > a.tokensSaved ? b : a);
    final avg = buckets.fold<int>(0, (s, b) => s + b.tokensSaved) ~/
        buckets.length;

    final buf = StringBuffer()
      ..writeln(
          'Tokens saved per day (${_dateOnly(start)} → ${_dateOnly(end)}, '
          'peak ${_fmt(maxValue)})')
      ..writeln()
      ..writeln('  $bars')
      ..writeln('  ${'^' * buckets.length}')
      ..writeln('  ${_dateOnly(start)}'
          '${' ' * (buckets.length - _dateOnly(start).length - _dateOnly(end).length - 1)}'
          '${_dateOnly(end)}')
      ..writeln()
      ..writeln(
          'Peak: ${_dateOnly(peak.day)} (${_fmt(peak.tokensSaved)} tokens)')
      ..write('Avg:  ${_fmt(avg)} tokens/day');
    return buf.toString();
  }

  static String _bar(int value, int max) {
    if (value <= 0) return ' ';
    final ratio = value / max;
    final idx = (ratio * (_blocks.length - 1)).round().clamp(0, _blocks.length - 1);
    return _blocks[idx];
  }

  static String _dateOnly(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$dd';
  }

  static String _fmt(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000 * 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}
