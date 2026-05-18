// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:test/test.dart';

void main() {
  group('InvocationRepo', () {
    late FlartDatabase db;
    late InvocationRepo repo;

    setUp(() {
      db = FlartDatabase.open();
      addTearDown(db.dispose);
      repo = InvocationRepo(db);
    });

    InvocationRecord makeRecord({
      DateTime? timestamp,
      String projectPath = '/p/a',
      String module = 'filter',
      String command = 'analyze',
      String? args,
      String? teePath,
      Map<String, Object?>? metadata,
      bool wasTruncated = false,
    }) =>
        InvocationRecord(
          timestamp: timestamp ?? DateTime.utc(2026, 5, 17, 12),
          projectPath: projectPath,
          module: module,
          command: command,
          args: args,
          rawBytes: 1000,
          filteredBytes: 200,
          rawChars: 1000,
          filteredChars: 200,
          estRawTokens: 264,
          estFiltTokens: 53,
          durationMs: 250,
          exitCode: 0,
          wasTruncated: wasTruncated,
          teePath: teePath,
          metadata: metadata,
        );

    test('insert returns row id, count tracks growth', () {
      expect(repo.count(), 0);
      final id1 = repo.insert(makeRecord());
      final id2 = repo.insert(makeRecord());
      expect(id1, isPositive);
      expect(id2, greaterThan(id1));
      expect(repo.count(), 2);
    });

    test('roundtrips all fields including metadata JSON', () {
      final r = makeRecord(
        args: 'lib/',
        teePath: '/tmp/tee.log',
        metadata: {'errors': 3, 'warnings_unique': 8, 'flutter': '3.27.0'},
        wasTruncated: true,
      );
      repo.insert(r);
      final got = repo.findRange().single;
      expect(got.id, isNotNull);
      expect(got.timestamp, r.timestamp);
      expect(got.projectPath, r.projectPath);
      expect(got.module, r.module);
      expect(got.command, r.command);
      expect(got.args, 'lib/');
      expect(got.teePath, '/tmp/tee.log');
      expect(got.wasTruncated, isTrue);
      expect(got.metadata, {
        'errors': 3,
        'warnings_unique': 8,
        'flutter': '3.27.0',
      });
    });

    test('null metadata stays null after roundtrip', () {
      repo.insert(makeRecord());
      final got = repo.findRange().single;
      expect(got.metadata, isNull);
    });

    test('findRange filters by since/until', () {
      final t0 = DateTime.utc(2026, 1, 1);
      repo.insert(makeRecord(timestamp: t0));
      repo.insert(makeRecord(timestamp: t0.add(const Duration(days: 1))));
      repo.insert(makeRecord(timestamp: t0.add(const Duration(days: 2))));

      final mid = repo.findRange(
        since: t0.add(const Duration(days: 1)),
        until: t0.add(const Duration(days: 2)),
      );
      expect(mid.length, 1);
      expect(mid.single.timestamp, t0.add(const Duration(days: 1)));
    });

    test('findRange filters by project/command/module independently', () {
      repo.insert(makeRecord(projectPath: '/p/a', command: 'analyze'));
      repo.insert(makeRecord(projectPath: '/p/b', command: 'analyze'));
      repo.insert(
          makeRecord(projectPath: '/p/a', command: 'test', module: 'filter'));
      repo.insert(makeRecord(
          projectPath: '/p/a', command: 'exec', module: 'executor'));

      expect(repo.findRange(projectPath: '/p/a').length, 3);
      expect(repo.findRange(command: 'analyze').length, 2);
      expect(repo.findRange(module: 'executor').length, 1);
      expect(
        repo.findRange(projectPath: '/p/a', command: 'analyze').length,
        1,
      );
    });

    test('findRange orders by timestamp DESC and respects limit', () {
      final t0 = DateTime.utc(2026, 1, 1);
      repo.insert(makeRecord(timestamp: t0));
      repo.insert(makeRecord(timestamp: t0.add(const Duration(seconds: 1))));
      repo.insert(makeRecord(timestamp: t0.add(const Duration(seconds: 2))));

      final two = repo.findRange(limit: 2);
      expect(two.length, 2);
      expect(two.first.timestamp, t0.add(const Duration(seconds: 2)));
      expect(two[1].timestamp, t0.add(const Duration(seconds: 1)));
    });
  });
}
