// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FlartDatabase.open', () {
    test('in-memory opens and applies migrations', () {
      final db = FlartDatabase.open();
      addTearDown(db.dispose);
      expect(db.isInMemory, isTrue);

      final invocations = db.raw
          .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='invocations'")
          .toList();
      expect(invocations, isNotEmpty);
    });

    test("explicit ':memory:' path is also treated as in-memory", () {
      final db = FlartDatabase.open(path: ':memory:');
      addTearDown(db.dispose);
      expect(db.isInMemory, isTrue);
    });

    test('on-disk creates parent dirs and persists between handles', () {
      final tmp = Directory.systemTemp.createTempSync('flart_db_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dbPath = p.join(tmp.path, 'nested', 'dir', 'savings.db');

      final db1 = FlartDatabase.open(path: dbPath);
      db1.raw.execute(
        '''
        INSERT INTO invocations (
          timestamp, project_path, module, command,
          raw_bytes, filtered_bytes, raw_chars, filtered_chars,
          est_raw_tokens, est_filt_tokens, duration_ms, exit_code
        ) VALUES (1, '/p', 'filter', 'analyze', 0, 0, 0, 0, 0, 0, 0, 0)
        ''',
      );
      db1.dispose();

      final db2 = FlartDatabase.open(path: dbPath);
      addTearDown(db2.dispose);
      expect(
        db2.raw.select('SELECT COUNT(*) AS c FROM invocations').first['c'],
        1,
      );
    });

    test('on-disk applies WAL + busy_timeout + foreign_keys pragmas', () {
      final tmp = Directory.systemTemp.createTempSync('flart_db_pragma_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dbPath = p.join(tmp.path, 'savings.db');

      final db = FlartDatabase.open(path: dbPath);
      addTearDown(db.dispose);

      expect(
        (db.raw.select('PRAGMA journal_mode').first['journal_mode'] as String)
            .toLowerCase(),
        'wal',
      );
      expect(db.raw.select('PRAGMA busy_timeout').first['timeout'], 5000);
      expect(db.raw.select('PRAGMA foreign_keys').first['foreign_keys'], 1);
    });

    test('in-memory skips WAL pragma (would be a no-op anyway)', () {
      final db = FlartDatabase.open();
      addTearDown(db.dispose);
      // sqlite reports 'memory' for in-memory dbs regardless of pragma.
      final mode = (db.raw.select('PRAGMA journal_mode').first['journal_mode']
              as String)
          .toLowerCase();
      expect(mode, isNot('wal'));
    });
  });
}
