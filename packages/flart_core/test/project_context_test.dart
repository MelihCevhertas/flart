// ignore_for_file: depend_on_referenced_packages
// `test` is a workspace-level dev dependency (see env_test.dart for context).

import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ProjectContext.detect', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_proj_ctx_');
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    test('finds pubspec.yaml in start directory', () {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('name: x');
      final ctx = ProjectContext.detect(startDir: tmp.path);
      expect(ctx.hasFlutterProject, isTrue);
      expect(ctx.root, _resolve(tmp.path));
    });

    test('finds pubspec.yaml in a parent directory', () {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('name: x');
      final nested = Directory(p.join(tmp.path, 'lib', 'features', 'auth'))
        ..createSync(recursive: true);

      final ctx = ProjectContext.detect(startDir: nested.path);
      expect(ctx.hasFlutterProject, isTrue);
      expect(ctx.root, _resolve(tmp.path));
    });

    test('falls back to start dir when no pubspec is found', () {
      // tmp has no pubspec.yaml — but parents (system temp, etc.) shouldn't
      // either. We cap depth at 1 to make the test deterministic.
      final ctx = ProjectContext.detect(startDir: tmp.path, maxDepth: 1);
      expect(ctx.hasFlutterProject, isFalse);
      expect(ctx.root, _resolve(tmp.path));
    });

    test('respects maxDepth — pubspec just past the limit is not found', () {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('name: x');
      final twoDeep = Directory(p.join(tmp.path, 'a', 'b'))
        ..createSync(recursive: true);

      // maxDepth=2 walks: b → a. That's 2 iterations; tmp is the 3rd.
      final shallow = ProjectContext.detect(startDir: twoDeep.path, maxDepth: 2);
      expect(shallow.hasFlutterProject, isFalse);

      final deep = ProjectContext.detect(startDir: twoDeep.path, maxDepth: 3);
      expect(deep.hasFlutterProject, isTrue);
      expect(deep.root, _resolve(tmp.path));
    });
  });

  group('ProjectContext.isFlutterPackage', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_flutter_detect_');
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    ProjectContext ctxFor(String pubspecBody) {
      File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync(pubspecBody);
      return ProjectContext.detect(startDir: tmp.path);
    }

    test('flutter under dependencies → true', () {
      final c = ctxFor('''
name: app
dependencies:
  flutter:
    sdk: flutter
''');
      expect(c.isFlutterPackage(), isTrue);
    });

    test('flutter_test under dev_dependencies → true', () {
      final c = ctxFor('''
name: pkg
dev_dependencies:
  flutter_test:
    sdk: flutter
''');
      expect(c.isFlutterPackage(), isTrue);
    });

    test('flutter under environment constraint → true', () {
      final c = ctxFor('''
name: pkg
environment:
  sdk: ^3.5.0
  flutter: ^3.0.0
''');
      expect(c.isFlutterPackage(), isTrue);
    });

    test('pure-Dart package → false', () {
      final c = ctxFor('''
name: pure_dart
environment:
  sdk: ^3.5.0
dependencies:
  yaml: ^3.1.2
''');
      expect(c.isFlutterPackage(), isFalse);
    });

    test('missing pubspec → false', () {
      final c = ProjectContext.detect(startDir: tmp.path, maxDepth: 1);
      expect(c.isFlutterPackage(), isFalse);
    });

    test('malformed pubspec YAML → false (defensive)', () {
      final c = ctxFor('not: : : valid : yaml');
      expect(c.isFlutterPackage(), isFalse);
    });
  });
}

/// Mirrors the symlink resolution `ProjectContext.detect` performs so test
/// assertions match on macOS where `/var → /private/var`.
String _resolve(String path) => Directory(path).resolveSymbolicLinksSync();
