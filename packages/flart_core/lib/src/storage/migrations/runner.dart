import 'package:sqlite3/sqlite3.dart';

/// A single forward-only schema migration. Implementations must be additive
/// (no DROP / RENAME) per Plan Section 16.4.
abstract class Migration {
  int get version;

  /// SQL statements to run, in order, inside a transaction.
  List<String> get statements;
}

/// Applies pending migrations to a [Database].
///
/// Maintains a `schema_version` meta-table (auto-created here, not in any
/// migration). Each migration runs in its own transaction; on failure the
/// transaction rolls back and the exception is rethrown — partial schema
/// changes never land.
class MigrationRunner {
  final DateTime Function() _now;

  MigrationRunner({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Runs every migration in [migrations] whose [Migration.version] is greater
  /// than the highest applied version. Returns the final applied version.
  int run(Database db, List<Migration> migrations) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL
      )
    ''');
    final sorted = [...migrations]
      ..sort((a, b) => a.version.compareTo(b.version));
    final applied = currentVersion(db);
    for (final m in sorted) {
      if (m.version <= applied) continue;
      _applyOne(db, m);
    }
    return currentVersion(db);
  }

  /// Highest applied migration version, or 0 if none.
  int currentVersion(Database db) {
    final row = db
        .select('SELECT COALESCE(MAX(version), 0) AS v FROM schema_version')
        .first;
    return row['v'] as int;
  }

  void _applyOne(Database db, Migration m) {
    db.execute('BEGIN');
    try {
      for (final stmt in m.statements) {
        db.execute(stmt);
      }
      db.execute(
        'INSERT INTO schema_version (version, applied_at) VALUES (?, ?)',
        [m.version, _now().millisecondsSinceEpoch ~/ 1000],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
