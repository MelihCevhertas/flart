// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flart_savings/flart_savings.dart';
import 'package:test/test.dart';

void main() {
  final summary = SavingsSummary(
    invocations: 100,
    rawBytes: 1000000,
    filteredBytes: 100000,
    rawChars: 1000000,
    filteredChars: 100000,
    estRawTokens: 263158,
    estFiltTokens: 26316,
    oldest: DateTime.utc(2026, 1, 1),
    newest: DateTime.utc(2026, 5, 18),
  );
  final byModule = [
    const GroupedSavings(
      label: 'filter',
      invocations: 70,
      rawBytes: 700000,
      filteredBytes: 50000,
      estRawTokens: 184211,
      estFiltTokens: 13158,
    ),
    const GroupedSavings(
      label: 'executor',
      invocations: 30,
      rawBytes: 300000,
      filteredBytes: 50000,
      estRawTokens: 78947,
      estFiltTokens: 13158,
    ),
  ];
  final byCommand = [
    const GroupedSavings(
      label: 'analyze',
      invocations: 40,
      rawBytes: 400000,
      filteredBytes: 20000,
      estRawTokens: 105263,
      estFiltTokens: 5263,
    ),
  ];

  group('TextFormatter', () {
    test('empty summary prints helpful message', () {
      final out = TextFormatter().render(
        summary: const SavingsSummary(
          invocations: 0,
          rawBytes: 0,
          filteredBytes: 0,
          rawChars: 0,
          filteredChars: 0,
          estRawTokens: 0,
          estFiltTokens: 0,
        ),
        byModule: const [],
        byProject: const [],
        topCommands: const [],
      );
      expect(out, contains('No invocations recorded yet'));
    });

    test('headline emphasises tokens before bytes', () {
      final out = TextFormatter().render(
        summary: summary,
        byModule: byModule,
        byProject: const [],
        topCommands: byCommand,
      );
      // Token block appears before byte block.
      final tokenIdx = out.indexOf('Estimated tokens saved');
      final byteIdx = out.indexOf('Saved:');
      expect(tokenIdx, isNonNegative);
      expect(byteIdx, isNonNegative);
      expect(tokenIdx, lessThan(byteIdx));
      // Token-savings ratio rendered.
      expect(out, contains('%'));
    });

    test('byCommand table renders all rows', () {
      final body = TextFormatter().renderByCommand(byCommand);
      expect(body, contains('flart analyze'));
      expect(body, contains('40'));
    });

    test('sub-agent activations line appears only when count > 0', () {
      final noSubs = TextFormatter().render(
        summary: summary,
        byModule: byModule,
        byProject: const [],
        topCommands: byCommand,
      );
      expect(noSubs, isNot(contains('Sub-agent activations')));

      final withSubs = TextFormatter().render(
        summary: summary,
        byModule: byModule,
        byProject: const [],
        topCommands: byCommand,
        subagentActivations: 7,
      );
      expect(withSubs, contains('Sub-agent activations:'));
      expect(withSubs, contains('7'));
    });

    test('empty summary with sub-agent activations only still renders headline',
        () {
      final out = TextFormatter().render(
        summary: const SavingsSummary(
          invocations: 0,
          rawBytes: 0,
          filteredBytes: 0,
          rawChars: 0,
          filteredChars: 0,
          estRawTokens: 0,
          estFiltTokens: 0,
        ),
        byModule: const [],
        byProject: const [],
        topCommands: const [],
        subagentActivations: 3,
      );
      expect(out, contains('Sub-agent activations:'));
      expect(out, isNot(contains('No invocations recorded yet')));
    });
  });

  group('JsonFormatter', () {
    test('roundtrips through jsonDecode with stable keys', () {
      final body = JsonFormatter().render(
        summary: summary,
        byModule: byModule,
        byProject: const [],
        topCommands: byCommand,
        generatedAt: DateTime.utc(2026, 5, 18, 12),
      );
      final decoded = jsonDecode(body) as Map<String, Object?>;
      expect(decoded['report_generated_at'], isA<String>());
      final s = decoded['summary'] as Map<String, Object?>;
      expect(s['invocations'], 100);
      expect(s['est_tokens_saved'], summary.tokensSaved);
      // v0.2.0: subagent_activations key is always present, default 0.
      expect(s['subagent_activations'], 0);
      final modules = decoded['by_module'] as List;
      expect(modules.length, 2);
      expect((modules.first as Map)['label'], 'filter');
    });

    test('subagent_activations carries through when provided', () {
      final body = JsonFormatter().render(
        summary: summary,
        byModule: byModule,
        byProject: const [],
        topCommands: byCommand,
        subagentActivations: 12,
        generatedAt: DateTime.utc(2026, 5, 18, 12),
      );
      final decoded = jsonDecode(body) as Map<String, Object?>;
      final s = decoded['summary'] as Map<String, Object?>;
      expect(s['subagent_activations'], 12);
    });
  });

  group('CsvFormatter', () {
    test('header + rows present, dimensions distinct', () {
      final body = CsvFormatter().render(
        byModule: byModule,
        byCommand: byCommand,
        byProject: const [],
      );
      final lines = body.split('\n').where((l) => l.isNotEmpty).toList();
      expect(lines.first, startsWith('dimension,label,invocations'));
      expect(lines.any((l) => l.startsWith('module,filter,')), isTrue);
      expect(lines.any((l) => l.startsWith('module,executor,')), isTrue);
      expect(lines.any((l) => l.startsWith('command,analyze,')), isTrue);
    });

    test('quotes commas and double-quotes in labels', () {
      final body = CsvFormatter().render(
        byModule: const [
          GroupedSavings(
            label: 'has,comma',
            invocations: 1,
            rawBytes: 100,
            filteredBytes: 10,
            estRawTokens: 26,
            estFiltTokens: 3,
          ),
        ],
        byCommand: const [],
        byProject: const [],
      );
      expect(body, contains('"has,comma"'));
    });
  });

  group('GraphFormatter', () {
    test('empty buckets → "No data to graph."', () {
      expect(GraphFormatter().render(const []), 'No data to graph.\n');
    });

    test('all-zero buckets → "No tokens saved in this window."', () {
      final buckets = List.generate(
        7,
        (i) => DailyBucket(
          day: DateTime.utc(2026, 5, 12).add(Duration(days: i)),
          invocations: 0,
          tokensSaved: 0,
        ),
      );
      expect(GraphFormatter().render(buckets),
          'No tokens saved in this window.\n');
    });

    test('non-empty buckets render Unicode bars + axis + peak/avg', () {
      final start = DateTime.utc(2026, 5, 12);
      final buckets = [
        DailyBucket(
            day: start, invocations: 1, tokensSaved: 100),
        DailyBucket(
            day: start.add(const Duration(days: 1)),
            invocations: 3,
            tokensSaved: 500),
        DailyBucket(
            day: start.add(const Duration(days: 2)),
            invocations: 5,
            tokensSaved: 1000),
      ];
      final body = GraphFormatter().render(buckets);
      expect(body, contains('Peak:'));
      expect(body, contains('Avg:'));
      expect(body, contains('2026-05-12'));
      expect(body, contains('2026-05-14'));
      // At least one block character appears.
      expect(body, contains(RegExp(r'[▁▂▃▄▅▆▇█]')));
    });
  });
}
