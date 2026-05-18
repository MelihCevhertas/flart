// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:test/test.dart';

void main() {
  group('InvocationTracker', () {
    late FlartDatabase db;
    late InvocationRepo repo;
    late ProjectContext project;
    final fixedNow = DateTime.utc(2026, 5, 17, 14, 30, 0);

    setUp(() {
      db = FlartDatabase.open();
      addTearDown(db.dispose);
      repo = InvocationRepo(db);
      project = const ProjectContext(
        root: '/proj/root',
        hasFlutterProject: true,
      );
    });

    InvocationTracker tracker({FlartEnv? env}) => InvocationTracker(
          repo: repo,
          estimator: const TokenEstimator(),
          project: project,
          env: env ?? const FlartEnv({}),
          now: () => fixedNow,
        );

    test('records byte/char/token counts and project context', () async {
      final id = await tracker().record(
        module: 'filter',
        command: 'analyze',
        args: 'lib/',
        rawText: 'a' * 380, // 380 chars / 3.8 = 100 tokens
        filteredText: 'b' * 38, // 38 chars / 3.8 = 10 tokens
        durationMs: 1234,
        exitCode: 0,
        metadata: const {'errors': 0, 'warnings_unique': 3},
      );
      expect(id, isNotNull);

      final got = repo.findRange().single;
      expect(got.projectPath, '/proj/root');
      expect(got.module, 'filter');
      expect(got.command, 'analyze');
      expect(got.args, 'lib/');
      expect(got.timestamp, fixedNow);
      expect(got.rawChars, 380);
      expect(got.filteredChars, 38);
      expect(got.rawBytes, 380); // ASCII so bytes == chars
      expect(got.filteredBytes, 38);
      expect(got.estRawTokens, 100);
      expect(got.estFiltTokens, 10);
      expect(got.durationMs, 1234);
      expect(got.exitCode, 0);
      expect(got.metadata, {'errors': 0, 'warnings_unique': 3});
    });

    test('UTF-8 multibyte chars: bytes > chars', () async {
      // 'ü' is 2 bytes in UTF-8 but 1 char.
      await tracker().record(
        module: 'filter',
        command: 'analyze',
        rawText: 'ü' * 10,
        filteredText: '',
        durationMs: 0,
        exitCode: 0,
      );
      final got = repo.findRange().single;
      expect(got.rawChars, 10);
      expect(got.rawBytes, 20);
    });

    test('FLART_NO_SAVINGS=1 makes record a no-op returning null', () async {
      final t = tracker(env: const FlartEnv({'FLART_NO_SAVINGS': '1'}));
      final id = await t.record(
        module: 'filter',
        command: 'analyze',
        rawText: 'hello',
        filteredText: 'hi',
        durationMs: 1,
        exitCode: 0,
      );
      expect(id, isNull);
      expect(repo.count(), 0);
    });

    test('empty metadata map stored as NULL, not empty JSON', () async {
      await tracker().record(
        module: 'filter',
        command: 'analyze',
        rawText: 'x',
        filteredText: 'x',
        durationMs: 0,
        exitCode: 0,
      );
      final got = repo.findRange().single;
      expect(got.metadata, isNull);
    });
  });
}
