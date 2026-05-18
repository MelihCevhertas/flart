import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'migrations/runner.dart';
import 'migrations/v1.dart';

/// Opens a SQLite database for flart, applies the standard pragmas, and runs
/// any pending migrations.
///
/// Constructor parameter [path]:
/// - `null` or `':memory:'` → in-memory database (used in unit tests)
/// - any other value → on-disk path; parent directories are created if missing
///
/// Tests must never let this class touch `~/.local/share/flart/` — either
/// open in-memory or pass a `Directory.systemTemp.createTempSync()` path.
class FlartDatabase {
  final sqlite.Database raw;
  final bool isInMemory;
  final String pathOrInMemory;

  FlartDatabase._(this.raw, this.isInMemory, this.pathOrInMemory);

  factory FlartDatabase.open({
    String? path,
    List<Migration> migrations = allMigrations,
    DateTime Function()? now,
  }) {
    final inMemory = path == null || path == ':memory:';
    final db = inMemory ? sqlite.sqlite3.openInMemory() : _openOnDisk(path);
    _applyPragmas(db, inMemory: inMemory);
    MigrationRunner(now: now).run(db, migrations);
    return FlartDatabase._(db, inMemory, inMemory ? ':memory:' : path);
  }

  static sqlite.Database _openOnDisk(String path) {
    final dir = Directory(p.dirname(path));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return sqlite.sqlite3.open(path);
  }

  /// Pragmas per Plan Section 3.3. WAL is skipped for in-memory because it's
  /// not applicable; the other three apply uniformly.
  static void _applyPragmas(sqlite.Database db, {required bool inMemory}) {
    if (!inMemory) {
      db.execute('PRAGMA journal_mode = WAL');
    }
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA foreign_keys = ON');
  }

  /// Releases the SQLite handle. Idempotent under our usage (the underlying
  /// `package:sqlite3` exposes `dispose()` once).
  void dispose() => raw.dispose();
}
