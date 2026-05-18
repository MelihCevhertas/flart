// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  group('MigrationRunner', () {
    late Database db;

    setUp(() {
      db = sqlite3.openInMemory();
      addTearDown(db.dispose);
    });

    test('creates schema_version table and applies v1', () {
      final runner = MigrationRunner();
      final finalVersion = runner.run(db, allMigrations);
      expect(finalVersion, 1);

      final tables = db
          .select(
              "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
          .map((r) => r['name'])
          .toList();
      expect(tables, containsAll(<String>['invocations', 'schema_version']));
    });

    test('schema_version row recorded with epoch seconds', () {
      final fixed = DateTime.utc(2026, 5, 17, 12, 0, 0);
      MigrationRunner(now: () => fixed).run(db, allMigrations);
      final row = db.select('SELECT * FROM schema_version').first;
      expect(row['version'], 1);
      expect(row['applied_at'], fixed.millisecondsSinceEpoch ~/ 1000);
    });

    test('second run is a no-op (idempotent)', () {
      final runner = MigrationRunner();
      runner.run(db, allMigrations);
      runner.run(db, allMigrations);
      final rows = db.select('SELECT COUNT(*) AS c FROM schema_version').first;
      expect(rows['c'], 1);
    });

    test('failing migration rolls back fully', () {
      final broken = _BrokenMigration();
      final runner = MigrationRunner();
      expect(() => runner.run(db, [broken]), throwsA(isA<SqliteException>()));

      // Verify partial table was rolled back.
      final tables = db
          .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='partial'")
          .toList();
      expect(tables, isEmpty);
      // schema_version still empty.
      expect(
        db.select('SELECT COUNT(*) AS c FROM schema_version').first['c'],
        0,
      );
    });

    test('expected indexes are created', () {
      MigrationRunner().run(db, allMigrations);
      final indexes = db
          .select(
              "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_invocations%'")
          .map((r) => r['name'])
          .toSet();
      expect(
        indexes,
        containsAll(<String>{
          'idx_invocations_timestamp',
          'idx_invocations_project',
          'idx_invocations_command',
        }),
      );
    });
  });
}

class _BrokenMigration implements Migration {
  @override
  int get version => 99;

  @override
  List<String> get statements => const [
        'CREATE TABLE partial (id INTEGER)',
        'CREATE TABLE partial (id INTEGER)', // intentional dup → error
      ];
}
