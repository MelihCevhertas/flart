import 'package:flart_core/flart_core.dart';
import 'package:meta/meta.dart';

/// Aggregated view of all invocations matching a filter. Plan Section 6.3.
@immutable
class SavingsSummary {
  final int invocations;
  final int rawBytes;
  final int filteredBytes;
  final int rawChars;
  final int filteredChars;
  final int estRawTokens;
  final int estFiltTokens;
  final DateTime? since;
  final DateTime? until;
  final DateTime? oldest;
  final DateTime? newest;

  const SavingsSummary({
    required this.invocations,
    required this.rawBytes,
    required this.filteredBytes,
    required this.rawChars,
    required this.filteredChars,
    required this.estRawTokens,
    required this.estFiltTokens,
    this.since,
    this.until,
    this.oldest,
    this.newest,
  });

  /// Bytes saved divided by raw bytes (0-1). Returns 0 when raw==0.
  double get savingsRatio =>
      rawBytes == 0 ? 0 : (rawBytes - filteredBytes) / rawBytes;

  /// Tokens saved divided by raw tokens (0-1). Returns 0 when raw==0.
  double get tokenSavingsRatio =>
      estRawTokens == 0 ? 0 : (estRawTokens - estFiltTokens) / estRawTokens;

  int get bytesSaved => rawBytes - filteredBytes;
  int get tokensSaved => estRawTokens - estFiltTokens;
}

/// One bucket in a group-by query (module/command/project).
@immutable
class GroupedSavings {
  final String label;
  final int invocations;
  final int rawBytes;
  final int filteredBytes;
  final int estRawTokens;
  final int estFiltTokens;

  const GroupedSavings({
    required this.label,
    required this.invocations,
    required this.rawBytes,
    required this.filteredBytes,
    required this.estRawTokens,
    required this.estFiltTokens,
  });

  int get bytesSaved => rawBytes - filteredBytes;
  int get tokensSaved => estRawTokens - estFiltTokens;
  double get savingsRatio =>
      rawBytes == 0 ? 0 : bytesSaved / rawBytes;
}

/// One time-series bucket for the `--graph` formatter.
@immutable
class DailyBucket {
  final DateTime day;
  final int invocations;
  final int tokensSaved;

  const DailyBucket({
    required this.day,
    required this.invocations,
    required this.tokensSaved,
  });
}

/// Read-only SQL aggregator over the `invocations` table. Lives in
/// `flart_savings` so the reporter has a narrow API to depend on — the CLI
/// command never writes the database.
class Aggregator {
  final FlartDatabase db;

  Aggregator(this.db);

  /// Single-row summary filtered by [since], [until], [projectPath].
  SavingsSummary summary({
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    if (since != null) {
      where.add('timestamp >= ?');
      params.add(since.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (until != null) {
      where.add('timestamp < ?');
      params.add(until.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (projectPath != null) {
      where.add('project_path = ?');
      params.add(projectPath);
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final row = db.raw.select(
      '''
      SELECT
        COUNT(*)                       AS invocations,
        COALESCE(SUM(raw_bytes), 0)       AS raw_bytes,
        COALESCE(SUM(filtered_bytes), 0)  AS filtered_bytes,
        COALESCE(SUM(raw_chars), 0)       AS raw_chars,
        COALESCE(SUM(filtered_chars), 0)  AS filtered_chars,
        COALESCE(SUM(est_raw_tokens), 0)  AS est_raw_tokens,
        COALESCE(SUM(est_filt_tokens), 0) AS est_filt_tokens,
        MIN(timestamp)                 AS oldest,
        MAX(timestamp)                 AS newest
      FROM invocations
      $whereClause
      ''',
      params,
    ).first;
    DateTime? toDate(Object? v) =>
        v is int ? DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true) : null;
    return SavingsSummary(
      invocations: row['invocations'] as int,
      rawBytes: row['raw_bytes'] as int,
      filteredBytes: row['filtered_bytes'] as int,
      rawChars: row['raw_chars'] as int,
      filteredChars: row['filtered_chars'] as int,
      estRawTokens: row['est_raw_tokens'] as int,
      estFiltTokens: row['est_filt_tokens'] as int,
      since: since,
      until: until,
      oldest: toDate(row['oldest']),
      newest: toDate(row['newest']),
    );
  }

  List<GroupedSavings> byModule({
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) =>
      _groupBy('module', since: since, until: until, projectPath: projectPath);

  List<GroupedSavings> byCommand({
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) =>
      _groupBy('command', since: since, until: until, projectPath: projectPath);

  List<GroupedSavings> byProject({
    DateTime? since,
    DateTime? until,
  }) =>
      _groupBy('project_path', since: since, until: until);

  /// Top-N invocations sorted by absolute tokens saved descending.
  List<InvocationRecord> top({
    int limit = 10,
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    if (since != null) {
      where.add('timestamp >= ?');
      params.add(since.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (until != null) {
      where.add('timestamp < ?');
      params.add(until.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (projectPath != null) {
      where.add('project_path = ?');
      params.add(projectPath);
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    params.add(limit);
    return db.raw
        .select(
          '''
          SELECT * FROM invocations
          $whereClause
          ORDER BY (est_raw_tokens - est_filt_tokens) DESC
          LIMIT ?
          ''',
          params,
        )
        .map(InvocationRecord.fromRow)
        .toList();
  }

  /// Most recent N invocations (DESC by timestamp).
  List<InvocationRecord> details({
    int limit = 20,
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) {
    return InvocationRepo(db).findRange(
      since: since,
      until: until,
      projectPath: projectPath,
      limit: limit,
    );
  }

  /// Sub-agent activation count for the given window (v0.2.0). Lives in a
  /// separate table from `invocations`; this getter is the reporter's single
  /// entry point so the CLI doesn't have to depend on [SubagentActivationRepo]
  /// directly. Returns 0 when the table is missing (older DBs pre-migration).
  int subagentActivationsCount({
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) {
    try {
      return SubagentActivationRepo(db)
          .count(since: since, until: until, projectPath: projectPath);
    } catch (_) {
      return 0;
    }
  }

  /// Daily buckets (UTC midnight) over the last [days] days.
  List<DailyBucket> dailyBuckets({int days = 30, DateTime Function()? now}) {
    final nowDt = (now ?? DateTime.now)().toUtc();
    final start = DateTime.utc(nowDt.year, nowDt.month, nowDt.day)
        .subtract(Duration(days: days - 1));
    final rows = db.raw.select(
      '''
      SELECT
        CAST(timestamp / 86400 AS INTEGER) AS day_epoch,
        COUNT(*) AS invocations,
        SUM(est_raw_tokens - est_filt_tokens) AS tokens_saved
      FROM invocations
      WHERE timestamp >= ?
      GROUP BY day_epoch
      ORDER BY day_epoch ASC
      ''',
      [start.millisecondsSinceEpoch ~/ 1000],
    );
    final byDay = <DateTime, DailyBucket>{};
    for (final row in rows) {
      final epochDay = row['day_epoch'] as int;
      final day = DateTime.fromMillisecondsSinceEpoch(
        epochDay * 86400 * 1000,
        isUtc: true,
      );
      byDay[day] = DailyBucket(
        day: day,
        invocations: row['invocations'] as int,
        tokensSaved: (row['tokens_saved'] as int?) ?? 0,
      );
    }
    // Fill missing days with zero buckets so the graph has a stable x-axis.
    final out = <DailyBucket>[];
    for (var i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      out.add(byDay[d] ??
          DailyBucket(day: d, invocations: 0, tokensSaved: 0));
    }
    return out;
  }

  List<GroupedSavings> _groupBy(
    String column, {
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    if (since != null) {
      where.add('timestamp >= ?');
      params.add(since.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (until != null) {
      where.add('timestamp < ?');
      params.add(until.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (projectPath != null) {
      where.add('project_path = ?');
      params.add(projectPath);
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return db.raw
        .select(
          '''
          SELECT
            $column                                AS label,
            COUNT(*)                               AS invocations,
            COALESCE(SUM(raw_bytes), 0)            AS raw_bytes,
            COALESCE(SUM(filtered_bytes), 0)       AS filtered_bytes,
            COALESCE(SUM(est_raw_tokens), 0)       AS est_raw_tokens,
            COALESCE(SUM(est_filt_tokens), 0)      AS est_filt_tokens
          FROM invocations
          $whereClause
          GROUP BY $column
          ORDER BY (SUM(est_raw_tokens) - SUM(est_filt_tokens)) DESC
          ''',
          params,
        )
        .map((row) => GroupedSavings(
              label: row['label'] as String,
              invocations: row['invocations'] as int,
              rawBytes: row['raw_bytes'] as int,
              filteredBytes: row['filtered_bytes'] as int,
              estRawTokens: row['est_raw_tokens'] as int,
              estFiltTokens: row['est_filt_tokens'] as int,
            ))
        .toList();
  }
}
