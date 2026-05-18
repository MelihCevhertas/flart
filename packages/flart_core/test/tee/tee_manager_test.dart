// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('TeeManager.shouldTee', () {
    TeeConfig conf({bool enabled = true, TeeMode mode = TeeMode.failures}) =>
        TeeConfig(
          enabled: enabled,
          mode: mode,
          directory: null,
          maxFiles: 30,
          maxFileSizeMb: 5,
          minSizeBytes: 0,
        );

    test('disabled config → never tees', () {
      final m = TeeManager(
        config: conf(enabled: false),
        teeDirectory: '/tmp/x',
      );
      expect(m.shouldTee(0), isFalse);
      expect(m.shouldTee(1), isFalse);
    });

    test('mode=never → never tees even when enabled', () {
      final m = TeeManager(
        config: conf(mode: TeeMode.never),
        teeDirectory: '/tmp/x',
      );
      expect(m.shouldTee(1), isFalse);
    });

    test('mode=always → tees on success and failure', () {
      final m = TeeManager(
        config: conf(mode: TeeMode.always),
        teeDirectory: '/tmp/x',
      );
      expect(m.shouldTee(0), isTrue);
      expect(m.shouldTee(1), isTrue);
      expect(m.shouldTee(124), isTrue);
    });

    test('mode=failures → only on non-zero exit code', () {
      final m = TeeManager(
        config: conf(mode: TeeMode.failures),
        teeDirectory: '/tmp/x',
      );
      expect(m.shouldTee(0), isFalse);
      expect(m.shouldTee(1), isTrue);
    });
  });

  group('TeeManager.write', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_tee_');
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    TeeManager manager({
      int maxFiles = 30,
      int minSizeBytes = 0,
      DateTime? now,
    }) =>
        TeeManager(
          config: TeeConfig(
            enabled: true,
            mode: TeeMode.failures,
            directory: tmp.path,
            maxFiles: maxFiles,
            maxFileSizeMb: 5,
            minSizeBytes: minSizeBytes,
          ),
          teeDirectory: tmp.path,
          now: () => now ?? DateTime.utc(2026, 5, 17, 14, 30, 0),
        );

    test('writes file with epoch_slug.log filename', () async {
      final m = manager();
      final path = await m.write('flutter_test', 'some long output\n' * 50);
      expect(path, isNotNull);
      final epoch = DateTime.utc(2026, 5, 17, 14, 30, 0)
              .millisecondsSinceEpoch ~/
          1000;
      expect(p.basename(path!), '${epoch}_flutter_test.log');
      expect(File(path).readAsStringSync().startsWith('some long output'),
          isTrue);
    });

    test('returns null when content smaller than minSizeBytes', () async {
      final m = manager(minSizeBytes: 100);
      final path = await m.write('tiny', 'too small');
      expect(path, isNull);
      expect(tmp.listSync(), isEmpty);
    });

    test('sanitizes slug — non-alnum becomes underscore', () async {
      final m = manager();
      final path = await m.write('flutter/test apk', 'x' * 600);
      expect(path, isNotNull);
      expect(p.basename(path!), contains('flutter_test_apk'));
    });

    test('rotates oldest entries when over maxFiles', () async {
      // Plant 5 existing log files with monotonically increasing mtimes.
      for (var i = 0; i < 5; i++) {
        final f = File(p.join(tmp.path, '${1000 + i}_old.log'))
          ..writeAsStringSync('old $i');
        final mtime = DateTime.utc(2026, 1, 1).add(Duration(minutes: i));
        f.setLastModifiedSync(mtime);
      }
      // maxFiles=3 means after writing one new file we should keep 3 entries.
      final m = manager(maxFiles: 3, now: DateTime.utc(2026, 5, 17));
      await m.write('new', 'x' * 600);
      final remaining = tmp
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList()
        ..sort();
      expect(remaining.length, 3);
      // Newest file is present.
      expect(remaining.any((n) => n.contains('_new.log')), isTrue);
      // Oldest two are gone.
      expect(remaining.any((n) => n.startsWith('1000_old')), isFalse);
      expect(remaining.any((n) => n.startsWith('1001_old')), isFalse);
    });

    test('creates directory if missing', () async {
      final nested = p.join(tmp.path, 'nested', 'tee');
      final m = TeeManager(
        config: TeeConfig(
          enabled: true,
          mode: TeeMode.failures,
          directory: nested,
          maxFiles: 10,
          maxFileSizeMb: 5,
          minSizeBytes: 0,
        ),
        teeDirectory: nested,
      );
      final path = await m.write('first', 'x' * 600);
      expect(path, isNotNull);
      expect(Directory(nested).existsSync(), isTrue);
    });
  });
}
