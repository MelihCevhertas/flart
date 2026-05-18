// ignore_for_file: depend_on_referenced_packages
// `test` is a workspace-level dev dependency (see env_test.dart for context).

import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Config.defaults', () {
    test('matches the documented Section 3.2 values', () {
      final c = Config.defaults();
      expect(c.tokenEstimation.charsPerToken, 3.8);
      expect(c.tokenEstimation.estimatedDeviation, 0.15);
      expect(c.tee.enabled, isTrue);
      expect(c.tee.mode, TeeMode.failures);
      expect(c.tee.directory, isNull);
      expect(c.tee.maxFiles, 30);
      expect(c.tee.maxFileSizeMb, 5);
      expect(c.tee.minSizeBytes, 500);
      expect(c.filters.maxFailuresShown, 15);
      expect(c.filters.maxWarningsShown, 50);
      expect(c.filters.truncateLongMessagesAt, 300);
      expect(c.filters.ultraCompact, isFalse);
      expect(c.executor.timeoutSeconds, 60);
      expect(c.executor.maxOutputBytes, 65536);
      expect(c.executor.headRatio, 0.6);
      expect(
        c.executor.allowedRuntimes,
        ['dart', 'bash', 'python', 'javascript'],
      );
      expect(c.savings.enabled, isTrue);
      expect(c.savings.databasePath, isNull);
      expect(c.savings.retentionDays, 365);
      expect(c.log.level, LogLevel.info);
      expect(c.log.file, isNull);
    });
  });

  group('Config.load', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_config_');
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    String writeYaml(String name, String content) {
      final f = File(p.join(tmp.path, name))..writeAsStringSync(content);
      return f.path;
    }

    test('global file overrides defaults', () {
      final g = writeYaml('global.yaml', '''
token_estimation:
  chars_per_token: 3.5
tee:
  mode: always
''');
      final c = Config.load(globalPath: g, env: const FlartEnv({}));
      expect(c.tokenEstimation.charsPerToken, 3.5);
      expect(c.tokenEstimation.estimatedDeviation, 0.15); // unchanged
      expect(c.tee.mode, TeeMode.always);
      expect(c.tee.enabled, isTrue); // unchanged
    });

    test('project file overrides global which overrides defaults', () {
      final g = writeYaml('global.yaml', '''
token_estimation:
  chars_per_token: 3.5
log:
  level: warn
''');
      final pr = writeYaml('project.yaml', '''
token_estimation:
  chars_per_token: 4.0
filters:
  ultra_compact: true
''');
      final c = Config.load(
        globalPath: g,
        projectPath: pr,
        env: const FlartEnv({}),
      );
      expect(c.tokenEstimation.charsPerToken, 4.0); // project wins
      expect(c.log.level, LogLevel.warn); // global wins (project silent)
      expect(c.filters.ultraCompact, isTrue);
    });

    test('list fields concatenate with dedup', () {
      final pr = writeYaml('project.yaml', '''
executor:
  allowed_runtimes:
    - ruby
    - dart
''');
      final c = Config.load(projectPath: pr, env: const FlartEnv({}));
      expect(
        c.executor.allowedRuntimes,
        ['dart', 'bash', 'python', 'javascript', 'ruby'],
        reason: 'base order preserved, ruby appended, dart deduped',
      );
    });

    test('missing files are silently ignored (defaults remain)', () {
      final c = Config.load(
        globalPath: p.join(tmp.path, 'nope.yaml'),
        projectPath: p.join(tmp.path, 'also-nope.yaml'),
        env: const FlartEnv({}),
      );
      expect(c.tokenEstimation.charsPerToken, 3.8);
    });

    test('malformed YAML throws FlartConfigException with actionable message',
        () {
      final bad = writeYaml('bad.yaml', '''
token_estimation:
  chars_per_token: : :
  : foo
''');
      expect(
        () => Config.load(globalPath: bad, env: const FlartEnv({})),
        throwsA(isA<FlartConfigException>().having(
          (e) => e.message,
          'message',
          allOf(contains(bad), contains('invalid YAML')),
        )),
      );
    });

    test('non-map YAML root throws actionable error', () {
      final scalar = writeYaml('scalar.yaml', '"just a string"\n');
      expect(
        () => Config.load(globalPath: scalar, env: const FlartEnv({})),
        throwsA(isA<FlartConfigException>().having(
          (e) => e.message,
          'message',
          contains('top-level YAML must be a map'),
        )),
      );
    });

    test('invalid tee.mode value gives helpful error', () {
      final pr = writeYaml('project.yaml', '''
tee:
  mode: maybe
''');
      expect(
        () => Config.load(projectPath: pr, env: const FlartEnv({})),
        throwsA(isA<FlartConfigException>().having(
          (e) => e.message,
          'message',
          contains('Allowed: failures, always, never'),
        )),
      );
    });

    test('tilde paths expand using FlartEnv.home', () {
      final pr = writeYaml('project.yaml', '''
tee:
  directory: ~/custom-tee
savings:
  database_path: ~/saved.db
log:
  file: ~/flart.log
''');
      final c = Config.load(
        projectPath: pr,
        env: const FlartEnv({'HOME': '/home/melih'}),
      );
      expect(c.tee.directory, '/home/melih/custom-tee');
      expect(c.savings.databasePath, '/home/melih/saved.db');
      expect(c.log.file, '/home/melih/flart.log');
    });

    test('wrong type for chars_per_token gives helpful error', () {
      final pr = writeYaml('project.yaml', '''
token_estimation:
  chars_per_token: "lots"
''');
      expect(
        () => Config.load(projectPath: pr, env: const FlartEnv({})),
        throwsA(isA<FlartConfigException>().having(
          (e) => e.message,
          'message',
          contains('token_estimation.chars_per_token'),
        )),
      );
    });
  });
}
