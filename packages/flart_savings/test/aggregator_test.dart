// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:flart_savings/flart_savings.dart';
import 'package:test/test.dart';

void main() {
  late FlartDatabase db;
  late InvocationRepo repo;
  late Aggregator agg;

  setUp(() {
    db = FlartDatabase.open();
    addTearDown(db.dispose);
    repo = InvocationRepo(db);
    agg = Aggregator(db);
  });

  InvocationRecord make({
    required DateTime timestamp,
    String project = '/p/a',
    String module = 'filter',
    String command = 'analyze',
    int raw = 1000,
    int filt = 100,
  }) =>
      InvocationRecord(
        timestamp: timestamp,
        projectPath: project,
        module: module,
        command: command,
        rawBytes: raw,
        filteredBytes: filt,
        rawChars: raw,
        filteredChars: filt,
        estRawTokens: (raw / 3.8).ceil(),
        estFiltTokens: (filt / 3.8).ceil(),
        durationMs: 100,
        exitCode: 0,
      );

  test('empty DB → invocations=0, ratios=0', () {
    final s = agg.summary();
    expect(s.invocations, 0);
    expect(s.savingsRatio, 0);
    expect(s.tokenSavingsRatio, 0);
    expect(s.oldest, isNull);
  });

  test('summary aggregates totals + oldest/newest', () {
    final t0 = DateTime.utc(2026, 5, 10);
    repo.insert(make(timestamp: t0, raw: 1000, filt: 100));
    repo.insert(make(timestamp: t0.add(const Duration(days: 3)), raw: 2000, filt: 200));
    repo.insert(make(timestamp: t0.add(const Duration(days: 7)), raw: 4000, filt: 300));

    final s = agg.summary();
    expect(s.invocations, 3);
    expect(s.rawBytes, 7000);
    expect(s.filteredBytes, 600);
    expect(s.bytesSaved, 6400);
    expect(s.savingsRatio, closeTo(6400 / 7000, 0.001));
    expect(s.oldest, t0);
    expect(s.newest, t0.add(const Duration(days: 7)));
  });

  test('summary respects --since/--until window', () {
    final t0 = DateTime.utc(2026, 5, 1);
    repo.insert(make(timestamp: t0));
    repo.insert(make(timestamp: t0.add(const Duration(days: 5))));
    repo.insert(make(timestamp: t0.add(const Duration(days: 10))));

    final s = agg.summary(
      since: t0.add(const Duration(days: 4)),
      until: t0.add(const Duration(days: 9)),
    );
    expect(s.invocations, 1);
  });

  test('byModule groups + sorts by tokens saved DESC', () {
    final t = DateTime.utc(2026, 5, 1);
    repo.insert(make(timestamp: t, module: 'filter', raw: 1000, filt: 100));
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 1)),
        module: 'filter',
        raw: 1000,
        filt: 100));
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 2)),
        module: 'executor',
        raw: 500,
        filt: 50));

    final rows = agg.byModule();
    expect(rows.length, 2);
    expect(rows.first.label, 'filter');
    expect(rows.first.invocations, 2);
    expect(rows.first.tokensSaved, greaterThan(rows.last.tokensSaved));
  });

  test('byCommand groups by flart subcommand', () {
    final t = DateTime.utc(2026, 5, 1);
    repo.insert(make(timestamp: t, command: 'analyze', raw: 5000, filt: 100));
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 1)),
        command: 'analyze',
        raw: 5000,
        filt: 100));
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 2)),
        command: 'test',
        raw: 1000,
        filt: 50));

    final rows = agg.byCommand();
    expect(rows.length, 2);
    expect(rows.first.label, 'analyze');
    expect(rows.first.invocations, 2);
  });

  test('byProject groups by project_path', () {
    final t = DateTime.utc(2026, 5, 1);
    repo.insert(make(timestamp: t, project: '/p/a'));
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 1)), project: '/p/b'));
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 2)), project: '/p/a'));
    final rows = agg.byProject();
    expect(rows.length, 2);
    final aRow = rows.firstWhere((g) => g.label == '/p/a');
    expect(aRow.invocations, 2);
  });

  test('top sorts by tokens saved DESC and respects limit', () {
    final t = DateTime.utc(2026, 5, 1);
    repo.insert(make(timestamp: t, raw: 100, filt: 50)); // saves ~13
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 1)),
        raw: 5000,
        filt: 100)); // saves ~1290
    repo.insert(make(
        timestamp: t.add(const Duration(seconds: 2)),
        raw: 1000,
        filt: 100)); // saves ~237

    final top = agg.top(limit: 2);
    expect(top.length, 2);
    expect(top.first.rawBytes, 5000);
    expect(top[1].rawBytes, 1000);
  });

  test('dailyBuckets pads missing days with zeros', () {
    final today = DateTime.utc(2026, 5, 18);
    repo.insert(make(
        timestamp: today.subtract(const Duration(days: 5)), raw: 1000, filt: 100));
    repo.insert(make(timestamp: today, raw: 2000, filt: 100));

    final buckets = agg.dailyBuckets(days: 7, now: () => today);
    expect(buckets.length, 7);
    expect(buckets.last.day, today);
    final nonZero = buckets.where((b) => b.invocations > 0).toList();
    expect(nonZero.length, 2);
  });
}
