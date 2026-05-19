// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:test/test.dart';

void main() {
  group('SubagentActivationRepo', () {
    late FlartDatabase db;
    late SubagentActivationRepo repo;

    setUp(() {
      db = FlartDatabase.open();
      addTearDown(db.dispose);
      repo = SubagentActivationRepo(db);
    });

    SubagentActivation make({
      DateTime? timestamp,
      String projectPath = '/p/a',
      String? parentSessionId,
    }) =>
        SubagentActivation(
          timestamp: timestamp ?? DateTime.utc(2026, 5, 17, 12),
          projectPath: projectPath,
          parentSessionId: parentSessionId,
        );

    test('insert returns id, count tracks growth', () {
      expect(repo.count(), 0);
      final id1 = repo.insert(make());
      final id2 = repo.insert(make(parentSessionId: 'sess-xyz'));
      expect(id1, isPositive);
      expect(id2, greaterThan(id1));
      expect(repo.count(), 2);
    });

    test('roundtrips fields including nullable session id', () {
      repo.insert(make(parentSessionId: 'abc-123'));
      repo.insert(make());
      final rows = repo.recent();
      expect(rows.length, 2);
      expect(rows.any((r) => r.parentSessionId == 'abc-123'), isTrue);
      expect(rows.any((r) => r.parentSessionId == null), isTrue);
    });

    test('count filters by since/until/projectPath', () {
      repo.insert(make(timestamp: DateTime.utc(2026, 5, 10), projectPath: '/p/a'));
      repo.insert(make(timestamp: DateTime.utc(2026, 5, 15), projectPath: '/p/a'));
      repo.insert(make(timestamp: DateTime.utc(2026, 5, 15), projectPath: '/p/b'));

      expect(repo.count(), 3);
      expect(repo.count(projectPath: '/p/a'), 2);
      expect(repo.count(projectPath: '/p/b'), 1);
      expect(
        repo.count(since: DateTime.utc(2026, 5, 12)),
        2,
      );
      expect(
        repo.count(
          since: DateTime.utc(2026, 5, 12),
          until: DateTime.utc(2026, 5, 15, 23, 59),
          projectPath: '/p/a',
        ),
        1,
      );
    });

    test('recent returns rows DESC by timestamp', () {
      repo.insert(make(timestamp: DateTime.utc(2026, 5, 10)));
      repo.insert(make(timestamp: DateTime.utc(2026, 5, 15)));
      repo.insert(make(timestamp: DateTime.utc(2026, 5, 12)));
      final rows = repo.recent();
      expect(rows.map((r) => r.timestamp.day).toList(), [15, 12, 10]);
    });
  });
}
