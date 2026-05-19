import 'package:flart_core/flart_core.dart';

import '../aggregator.dart';

/// Plan Section 6.3 default text report. Token-first (Plan v1.7 A: agent
/// cost is the headline metric, bytes/chars are supplemental).
class TextFormatter {
  final double charsPerToken;
  final double estimatedDeviation; // ±%N suffix on the disclaimer

  TextFormatter({
    this.charsPerToken = 3.8,
    this.estimatedDeviation = 0.15,
  });

  String render({
    required SavingsSummary summary,
    required List<GroupedSavings> byModule,
    required List<GroupedSavings> byProject,
    required List<GroupedSavings> topCommands,
    int subagentActivations = 0,
  }) {
    final buf = StringBuffer();
    buf.writeln('flart Savings Report');
    buf.writeln('====================');
    buf.writeln();

    if (summary.invocations == 0 && subagentActivations == 0) {
      buf.writeln('No invocations recorded yet. Run flart commands first.');
      buf.write(_disclaimer());
      return buf.toString();
    }

    buf.writeln(_headline(summary));
    if (subagentActivations > 0) {
      buf.writeln('  Sub-agent activations:       ${_intStr(subagentActivations)}'
          '  (Task hook fires; no byte/token savings tracked)');
    }
    buf.writeln();
    if (byModule.isNotEmpty) {
      buf.writeln('By module:');
      for (final g in byModule) {
        buf.writeln('  ${g.label.padRight(10)} ${_invFmt(g.invocations)}'
            '  →  saved ${_tk(g.tokensSaved)}  (${(g.savingsRatio * 100).toStringAsFixed(0)}%)');
      }
      buf.writeln();
    }
    if (byProject.isNotEmpty) {
      buf.writeln('By project:');
      for (final g in byProject) {
        buf.writeln(
            '  ${_shortenPath(g.label).padRight(36)} ${_invFmt(g.invocations)}'
            '  →  saved ${_tk(g.tokensSaved)}');
      }
      buf.writeln();
    }
    if (topCommands.isNotEmpty) {
      buf.writeln('Top commands:');
      for (final g in topCommands) {
        buf.writeln('  flart ${g.label.padRight(14)}'
            '  →  saved ${_tk(g.tokensSaved)}'
            '  (${(g.savingsRatio * 100).toStringAsFixed(0)}%)');
      }
      buf.writeln();
    }
    buf.writeln(
        'Use `flart savings --details` for individual invocation breakdown.');
    buf.write(_disclaimer());
    return buf.toString();
  }

  String renderByCommand(List<GroupedSavings> rows) {
    final buf = StringBuffer();
    buf.writeln('Command                    Calls    Raw tokens   Filtered     Saved    %');
    for (final g in rows) {
      buf.writeln([
        'flart ${g.label}'.padRight(26),
        _intStr(g.invocations).padLeft(7),
        _intStr(g.estRawTokens).padLeft(13),
        _intStr(g.estFiltTokens).padLeft(11),
        _intStr(g.tokensSaved).padLeft(10),
        (g.savingsRatio * 100).toStringAsFixed(1).padLeft(6),
      ].join(' '));
    }
    return buf.toString();
  }

  String renderTopInvocations(
    List<InvocationRecord> records, {
    int limit = 10,
  }) {
    final buf = StringBuffer('Top $limit invocations (by tokens saved):\n');
    for (final r in records) {
      buf.writeln(
        '  [${r.timestamp.toIso8601String()}] flart ${r.command} ${r.args ?? ''}'
        '  →  saved ${_tk(r.estRawTokens - r.estFiltTokens)} tokens',
      );
    }
    return buf.toString();
  }

  String renderDetails(List<InvocationRecord> records) {
    final buf = StringBuffer(
        'Recent ${records.length} invocations:\n');
    for (final r in records) {
      buf.writeln(
        '  ${r.timestamp.toIso8601String()}  '
        'flart ${r.command} ${r.args ?? ''}  exit=${r.exitCode}  '
        '${_tk(r.estRawTokens)} → ${_tk(r.estFiltTokens)} tokens'
        '${r.teePath != null ? '  [teed]' : ''}',
      );
    }
    return buf.toString();
  }

  String _headline(SavingsSummary s) {
    final since = s.oldest?.toIso8601String().substring(0, 10) ?? '—';
    final buf = StringBuffer()
      ..writeln('All-time savings (since $since):')
      ..writeln('  Invocations:        ${_intStr(s.invocations)}')
      ..writeln('  Estimated raw tokens:        ${_intStr(s.estRawTokens)}')
      ..writeln('  Estimated filtered tokens:   ${_intStr(s.estFiltTokens)}')
      ..writeln('  Estimated tokens saved:      ${_intStr(s.tokensSaved)}'
          '  (${(s.tokenSavingsRatio * 100).toStringAsFixed(1)}%)')
      ..writeln()
      ..writeln('  Raw output:         ${_bytes(s.rawBytes)}')
      ..writeln('  Filtered output:    ${_bytes(s.filteredBytes)}')
      ..writeln('  Saved:              ${_bytes(s.bytesSaved)}'
          '  (${(s.savingsRatio * 100).toStringAsFixed(1)}%)');
    return buf.toString();
  }

  String _disclaimer() => '\nNote: Token sayıları tahminidir '
      '(chars / $charsPerToken formülü ile).\n'
      'Gerçek Claude tokenizasyonu ile ±%${(estimatedDeviation * 100).round()} sapma olabilir.\n'
      'Byte/karakter sayıları kesindir.\n';

  static String _bytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _tk(int n) {
    if (n < 1000) return n.toString();
    if (n < 1000 * 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  static String _intStr(int n) {
    // Thousands separators (1,234,567).
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _invFmt(int n) =>
      '${_intStr(n).padLeft(6)} invocations';

  static String _shortenPath(String absPath) {
    // /Users/foo/dev/project-a → ~/dev/project-a if HOME match;
    // otherwise keep tail components.
    final home = const String.fromEnvironment('HOME', defaultValue: '');
    if (home.isNotEmpty && absPath.startsWith(home)) {
      return '~${absPath.substring(home.length)}';
    }
    return absPath;
  }
}
