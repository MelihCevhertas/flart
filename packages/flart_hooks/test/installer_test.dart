// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:flart_core/flart_core.dart';
import 'package:flart_hooks/flart_hooks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('resolveConfigHome', () {
    test('FLART_CONFIG_DIR overrides everything', () {
      final env = FlartEnv({
        'FLART_CONFIG_DIR': '/tmp/flart-cfg',
        'XDG_CONFIG_HOME': '/should/lose',
        'HOME': '/home/x',
      });
      expect(resolveConfigHome(env), '/tmp/flart-cfg');
    });

    test('falls back to XDG_CONFIG_HOME', () {
      final env = FlartEnv({
        'XDG_CONFIG_HOME': '/xdg/cfg',
        'HOME': '/home/x',
      });
      expect(resolveConfigHome(env), '/xdg/cfg');
    });

    test('falls back to \$HOME/.config', () {
      final env = FlartEnv({'HOME': '/home/melih'});
      expect(resolveConfigHome(env), '/home/melih/.config');
    });

    test('throws when nothing is available', () {
      expect(() => resolveConfigHome(const FlartEnv({})),
          throwsA(isA<StateError>()));
    });
  });

  group('defaultHookScriptPath', () {
    test('joins config home + flart/hooks/rewrite.sh', () {
      expect(
        defaultHookScriptPath('/home/x/.config'),
        '/home/x/.config/flart/hooks/rewrite.sh',
      );
    });
  });

  group('atomicWriteString', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_atomic_');
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    test('writes content and removes the tmp sibling', () {
      final target = p.join(tmp.path, 'sub', 'a.txt');
      atomicWriteString(target, 'hello\n');
      expect(File(target).readAsStringSync(), 'hello\n');
      final leftovers = tmp.listSync(recursive: true).whereType<File>().where(
            (f) => p.basename(f.path).contains('.tmp.'),
          );
      expect(leftovers, isEmpty,
          reason: 'rename should leave no .tmp.<pid> file behind');
    });

    test('executable flag sets +x on the resulting file (Unix)', () {
      if (Platform.isWindows) {
        return;
      }
      final target = p.join(tmp.path, 'script.sh');
      atomicWriteString(target, '#!/usr/bin/env bash\necho hi\n',
          executable: true);
      final stat = File(target).statSync();
      // Owner execute bit (0100) present.
      expect(stat.mode & 0x40, isNot(0));
    });
  });

  group('HookInstaller — settings.json idempotency', () {
    late Directory tmp;
    late HookInstaller installer;
    late String settingsPath;
    late String hookScriptPath;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_inst_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      settingsPath = p.join(tmp.path, '.claude', 'settings.json');
      hookScriptPath = p.join(tmp.path, '.config', 'flart', 'hooks', 'rewrite.sh');
      installer = HookInstaller(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
      );
    });

    test('fresh install creates settings.json + hook script', () {
      installer.installAll();
      expect(File(hookScriptPath).existsSync(), isTrue);
      final settings = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, Object?>;
      final hooks = (settings['hooks'] as Map)['PreToolUse'] as List;
      expect(hooks.length, 1);
      final entry = hooks.first as Map;
      expect(entry['matcher'], 'Bash');
      expect((entry['hooks'] as List).first['command'], hookScriptPath);
    });

    test('install preserves unrelated fields in existing settings.json', () {
      Directory(p.dirname(settingsPath)).createSync(recursive: true);
      File(settingsPath).writeAsStringSync(jsonEncode({
        'theme': 'dark',
        'model': 'sonnet',
        'hooks': {
          'PreToolUse': [
            {
              'matcher': 'Bash',
              'hooks': [
                {'type': 'command', 'command': '/some/other/hook.sh'},
              ],
            },
          ],
        },
      }));
      installer.installAll();
      final settings = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, Object?>;
      // User's other fields preserved.
      expect(settings['theme'], 'dark');
      expect(settings['model'], 'sonnet');
      // PreToolUse now has BOTH entries (other hook untouched, flart added).
      final hooks = (settings['hooks'] as Map)['PreToolUse'] as List;
      expect(hooks.length, 2);
      expect(
        hooks.any((e) =>
            (e as Map)['matcher'] == 'Bash' &&
            ((e['hooks'] as List).first as Map)['command'] ==
                '/some/other/hook.sh'),
        isTrue,
      );
      expect(
        hooks.any((e) =>
            ((e as Map)['hooks'] as List).first['command'] == hookScriptPath),
        isTrue,
      );
    });

    test('second install updates the same entry (no duplicate)', () {
      installer.installAll();
      installer.installAll();
      final settings = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, Object?>;
      final hooks = (settings['hooks'] as Map)['PreToolUse'] as List;
      final flartEntries = hooks.where((e) =>
          ((e as Map)['hooks'] as List).first['command'] == hookScriptPath);
      expect(flartEntries.length, 1);
    });

    test('uninstall removes flart entry + deletes hook script, keeps others',
        () {
      // Plant another hook + install flart.
      Directory(p.dirname(settingsPath)).createSync(recursive: true);
      File(settingsPath).writeAsStringSync(jsonEncode({
        'hooks': {
          'PreToolUse': [
            {
              'matcher': 'Bash',
              'hooks': [
                {'type': 'command', 'command': '/some/other/hook.sh'},
              ],
            },
          ],
        },
      }));
      installer.installAll();
      installer.uninstallAll();
      expect(File(hookScriptPath).existsSync(), isFalse);
      final settings = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, Object?>;
      final hooks = (settings['hooks'] as Map)['PreToolUse'] as List;
      expect(hooks.length, 1);
      expect(
        ((hooks.first as Map)['hooks'] as List).first['command'],
        '/some/other/hook.sh',
      );
    });

    test('describeState reports installed vs missing', () {
      expect(installer.describeState(), contains('not installed'));
      installer.installAll();
      final state = installer.describeState();
      expect(state, contains('✓ $hookScriptPath'));
      expect(state, contains('✓ points to $hookScriptPath'));
    });
  });

  group('ProjectInstaller — CLAUDE.md marker management', () {
    late Directory tmp;
    late String claudeMdPath;
    late ProjectInstaller projectInstaller;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_claude_md_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      claudeMdPath = p.join(tmp.path, 'CLAUDE.md');
      projectInstaller = ProjectInstaller(claudeMdPath: claudeMdPath);
    });

    test('install creates file when absent', () {
      projectInstaller.installRoutingBlock();
      final content = File(claudeMdPath).readAsStringSync();
      expect(content, contains(claudeMdMarkerStart));
      expect(content, contains(claudeMdMarkerEnd));
      expect(content, contains('flart routing'));
    });

    test('install appends to existing CLAUDE.md without trashing content', () {
      const userContent = '# Project notes\n\nSome stuff here.\n';
      File(claudeMdPath).writeAsStringSync(userContent);
      projectInstaller.installRoutingBlock();
      final updated = File(claudeMdPath).readAsStringSync();
      expect(updated, startsWith(userContent));
      expect(updated, contains(claudeMdMarkerStart));
    });

    test('second install replaces existing block in-place', () {
      File(claudeMdPath).writeAsStringSync(
        '# Top\n\n$claudeMdMarkerStart\nOLD CONTENT\n$claudeMdMarkerEnd\n\n# Bottom\n',
      );
      projectInstaller.installRoutingBlock();
      final updated = File(claudeMdPath).readAsStringSync();
      // User's pre/post sections preserved.
      expect(updated, startsWith('# Top\n'));
      expect(updated, contains('# Bottom'));
      // Old block content gone.
      expect(updated, isNot(contains('OLD CONTENT')));
      // New block present.
      expect(updated, contains('flart routing'));
      // Exactly one marker pair (no duplication on second install).
      expect(_countOccurrences(updated, claudeMdMarkerStart), 1);
      expect(_countOccurrences(updated, claudeMdMarkerEnd), 1);
    });

    test('remove keeps surrounding user content, drops markers', () {
      File(claudeMdPath).writeAsStringSync(
        '# Top\n\n$claudeMdMarkerStart\nbody\n$claudeMdMarkerEnd\n\n# Bottom\n',
      );
      projectInstaller.removeRoutingBlock();
      final updated = File(claudeMdPath).readAsStringSync();
      expect(updated, contains('# Top'));
      expect(updated, contains('# Bottom'));
      expect(updated, isNot(contains(claudeMdMarkerStart)));
      expect(updated, isNot(contains('body')));
    });

    test('remove deletes file when only the block existed', () {
      File(claudeMdPath).writeAsStringSync(
        '$claudeMdMarkerStart\nbody\n$claudeMdMarkerEnd\n',
      );
      projectInstaller.removeRoutingBlock();
      expect(File(claudeMdPath).existsSync(), isFalse);
    });
  });

  group('HookChecker', () {
    late Directory tmp;
    late String settingsPath;
    late String hookScriptPath;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_check_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      settingsPath = p.join(tmp.path, '.claude', 'settings.json');
      hookScriptPath = p.join(tmp.path, '.config', 'flart', 'hooks', 'rewrite.sh');
    });

    test('clean install: all checks pass', () async {
      Directory(p.dirname(settingsPath)).createSync(recursive: true);
      Directory(p.dirname(hookScriptPath)).createSync(recursive: true);
      File(settingsPath).writeAsStringSync('{}');
      File(hookScriptPath).writeAsStringSync('#!/bin/bash\n');
      final checker = HookChecker(
        whichExe: (exe) async => '/fake/$exe',
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
      );
      expect(results.every((r) => r.ok), isTrue);
    });

    test('jq missing → fails with actionable hint', () async {
      final checker = HookChecker(
        whichExe: (exe) async => exe == 'jq' ? null : '/fake/$exe',
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
      );
      final jq = results.firstWhere((r) => r.label == 'jq');
      expect(jq.ok, isFalse);
      expect(jq.hint, contains('brew install jq'));
    });

    test('rendered table shows ✓/✗ with hint indentation', () async {
      final checker = HookChecker(
        whichExe: (exe) async => exe == 'flart' ? '/usr/local/bin/flart' : null,
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
      );
      final rendered = renderCheckTable(results);
      expect(rendered, contains('✓ flart binary'));
      expect(rendered, contains('✗ jq'));
      expect(rendered, contains('→ Install: brew install jq'));
    });
  });
}

int _countOccurrences(String text, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var idx = text.indexOf(needle);
  while (idx >= 0) {
    count++;
    idx = text.indexOf(needle, idx + needle.length);
  }
  return count;
}
