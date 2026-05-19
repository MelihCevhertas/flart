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
    late HookInstaller installerOldClaude;
    late String settingsPath;
    late String hookScriptPath;
    late String taskHookScriptPath;
    late String bashPostHookScriptPath;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_inst_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      settingsPath = p.join(tmp.path, '.claude', 'settings.json');
      hookScriptPath = p.join(tmp.path, '.config', 'flart', 'hooks', 'rewrite.sh');
      taskHookScriptPath = p.join(tmp.path, '.config', 'flart', 'hooks', 'task_hook.sh');
      bashPostHookScriptPath = p.join(tmp.path, '.config', 'flart', 'hooks', 'bash_post_hook.sh');
      installer = HookInstaller(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        bashPostHookScriptPath: bashPostHookScriptPath,
        claudeVersion: const ClaudeCodeVersion(2, 1, 144),
      );
      // Same paths, but Claude Code is too old → PostToolUse should be skipped.
      installerOldClaude = HookInstaller(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        bashPostHookScriptPath: bashPostHookScriptPath,
        claudeVersion: const ClaudeCodeVersion(2, 1, 119),
      );
    });

    List<Map<String, Object?>> entriesFor(String path, String event) {
      final settings = jsonDecode(File(path).readAsStringSync())
          as Map<String, Object?>;
      final hooks = settings['hooks'];
      if (hooks is! Map) return const [];
      final list = hooks[event];
      if (list is! List) return const [];
      return list.cast<Map<String, Object?>>();
    }

    test('fresh install writes all three scripts + PreToolUse + PostToolUse '
        '(modern Claude)', () {
      installer.installAll();
      expect(File(hookScriptPath).existsSync(), isTrue);
      expect(File(taskHookScriptPath).existsSync(), isTrue);
      expect(File(bashPostHookScriptPath).existsSync(), isTrue);

      final pre = entriesFor(settingsPath, 'PreToolUse');
      expect(pre.length, 2);
      expect(pre.map((e) => e['matcher']), containsAll(['Bash', 'Task']));

      final post = entriesFor(settingsPath, 'PostToolUse');
      expect(post.length, 1);
      expect(post.first['matcher'], 'Bash');
      expect((post.first['hooks'] as List).first['command'],
          bashPostHookScriptPath);
    });

    test('older Claude (< v2.1.121) → PostToolUse skipped with note', () {
      final messages = installerOldClaude.installAll();
      expect(File(hookScriptPath).existsSync(), isTrue);
      expect(File(taskHookScriptPath).existsSync(), isTrue);
      expect(File(bashPostHookScriptPath).existsSync(), isFalse,
          reason: 'no script when version is below the threshold');
      expect(messages.any((m) => m.contains('PostToolUse/Bash hook skipped')),
          isTrue);
      // settings.json has only PreToolUse entries — no PostToolUse key at all.
      final settings = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, Object?>;
      expect((settings['hooks'] as Map).containsKey('PostToolUse'), isFalse);
    });

    test('install preserves unrelated fields and other Bash hooks', () {
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
      expect(settings['theme'], 'dark');
      expect(settings['model'], 'sonnet');
      final pre = entriesFor(settingsPath, 'PreToolUse');
      // Unrelated Bash hook + flart Bash + flart Task = 3 entries.
      expect(pre.length, 3);
      expect(
        pre.any((e) =>
            e['matcher'] == 'Bash' &&
            ((e['hooks'] as List).first as Map)['command'] ==
                '/some/other/hook.sh'),
        isTrue,
      );
      expect(
        pre.any((e) =>
            ((e['hooks'] as List).first as Map)['command'] == hookScriptPath),
        isTrue,
      );
      expect(
        pre.any((e) =>
            ((e['hooks'] as List).first as Map)['command'] ==
            taskHookScriptPath),
        isTrue,
      );
      // PostToolUse Bash entry also added (modern Claude).
      final post = entriesFor(settingsPath, 'PostToolUse');
      expect(post.length, 1);
    });

    test('second install updates same entries (no duplicates)', () {
      installer.installAll();
      installer.installAll();
      final pre = entriesFor(settingsPath, 'PreToolUse');
      final post = entriesFor(settingsPath, 'PostToolUse');
      final flartCmds = [
        ...pre.map((e) => ((e['hooks'] as List).first as Map)['command']),
        ...post.map((e) => ((e['hooks'] as List).first as Map)['command']),
      ];
      expect(
        flartCmds.where((c) =>
            c == hookScriptPath ||
            c == taskHookScriptPath ||
            c == bashPostHookScriptPath),
        hasLength(3),
      );
    });

    test('uninstall purges all three flart entries + scripts, keeps others',
        () {
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
      expect(File(taskHookScriptPath).existsSync(), isFalse);
      expect(File(bashPostHookScriptPath).existsSync(), isFalse);
      final pre = entriesFor(settingsPath, 'PreToolUse');
      expect(pre.length, 1);
      expect(
        ((pre.first['hooks'] as List).first as Map)['command'],
        '/some/other/hook.sh',
      );
      final settings = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, Object?>;
      expect((settings['hooks'] as Map).containsKey('PostToolUse'), isFalse,
          reason: 'empty PostToolUse list should drop the key entirely');
    });

    test('uninstall also purges a stale PostToolUse entry when '
        'Claude was later downgraded', () {
      // Simulate: PostToolUse installed under modern Claude, then user
      // downgrades and runs `flart init --uninstall`. The entry must still
      // be removed even though the installer's claudeVersion is too low.
      installer.installAll();
      expect(File(bashPostHookScriptPath).existsSync(), isTrue);
      installerOldClaude.uninstallAll();
      expect(File(bashPostHookScriptPath).existsSync(), isFalse);
      final settings = jsonDecode(File(settingsPath).readAsStringSync())
          as Map<String, Object?>;
      expect((settings['hooks'] as Map?)?.containsKey('PostToolUse'),
          isNot(isTrue));
    });

    test('describeState reports Claude Code version + all three hooks', () {
      final state0 = installer.describeState();
      expect(state0, contains('Claude Code:'));
      expect(state0, contains('Hook script (Bash, PreToolUse)'));
      expect(state0, contains('Hook script (Task, PreToolUse)'));
      expect(state0, contains('Hook script (Bash, PostToolUse)'));
      expect(state0, contains('not installed'));
      installer.installAll();
      final state = installer.describeState();
      expect(state, contains('✓ $hookScriptPath'));
      expect(state, contains('✓ $taskHookScriptPath'));
      expect(state, contains('✓ $bashPostHookScriptPath'));
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
    late String taskHookScriptPath;
    late String bashPostHookScriptPath;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('flart_check_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      settingsPath = p.join(tmp.path, '.claude', 'settings.json');
      hookScriptPath = p.join(tmp.path, '.config', 'flart', 'hooks', 'rewrite.sh');
      taskHookScriptPath = p.join(tmp.path, '.config', 'flart', 'hooks', 'task_hook.sh');
      bashPostHookScriptPath =
          p.join(tmp.path, '.config', 'flart', 'hooks', 'bash_post_hook.sh');
    });

    test('clean install on modern Claude: all checks pass', () async {
      Directory(p.dirname(settingsPath)).createSync(recursive: true);
      Directory(p.dirname(hookScriptPath)).createSync(recursive: true);
      File(settingsPath).writeAsStringSync('{}');
      File(hookScriptPath).writeAsStringSync('#!/bin/bash\n');
      File(taskHookScriptPath).writeAsStringSync('#!/bin/bash\n');
      File(bashPostHookScriptPath).writeAsStringSync('#!/bin/bash\n');
      final checker = HookChecker(
        whichExe: (exe) async => '/fake/$exe',
        detectVersion: () async => const ClaudeCodeVersion(2, 1, 144),
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        bashPostHookScriptPath: bashPostHookScriptPath,
      );
      expect(results.every((r) => r.ok), isTrue);
    });

    test('older Claude → version row fails with upgrade hint, '
        'PostToolUse script absence is tolerated', () async {
      Directory(p.dirname(settingsPath)).createSync(recursive: true);
      Directory(p.dirname(hookScriptPath)).createSync(recursive: true);
      File(settingsPath).writeAsStringSync('{}');
      File(hookScriptPath).writeAsStringSync('#!/bin/bash\n');
      File(taskHookScriptPath).writeAsStringSync('#!/bin/bash\n');
      // bash_post_hook.sh intentionally absent.
      final checker = HookChecker(
        whichExe: (exe) async => '/fake/$exe',
        detectVersion: () async => const ClaudeCodeVersion(2, 1, 119),
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        bashPostHookScriptPath: bashPostHookScriptPath,
      );
      final claude = results.firstWhere((r) => r.label == 'Claude Code');
      expect(claude.ok, isTrue,
          reason: 'detected version is OK; only output mutation is gated');
      expect(claude.detail, contains('requires 2.1.121+'));
      expect(claude.hint, contains('Upgrade Claude Code'));
      // PostToolUse script row is "ok=true detail='skipped'" — not an error.
      final post = results.firstWhere(
          (r) => r.label == 'Hook script (Bash, PostToolUse)');
      expect(post.ok, isTrue);
      expect(post.detail, contains('skipped'));
    });

    test('jq missing → fails with actionable hint', () async {
      final checker = HookChecker(
        whichExe: (exe) async => exe == 'jq' ? null : '/fake/$exe',
        detectVersion: () async => const ClaudeCodeVersion(2, 1, 144),
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        bashPostHookScriptPath: bashPostHookScriptPath,
      );
      final jq = results.firstWhere((r) => r.label == 'jq');
      expect(jq.ok, isFalse);
      expect(jq.hint, contains('brew install jq'));
    });

    test('Task hook missing → reported with hint', () async {
      Directory(p.dirname(settingsPath)).createSync(recursive: true);
      Directory(p.dirname(hookScriptPath)).createSync(recursive: true);
      File(settingsPath).writeAsStringSync('{}');
      File(hookScriptPath).writeAsStringSync('#!/bin/bash\n');
      // task_hook.sh intentionally absent.
      final checker = HookChecker(
        whichExe: (exe) async => '/fake/$exe',
        detectVersion: () async => const ClaudeCodeVersion(2, 1, 144),
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
      );
      final task = results.firstWhere(
          (r) => r.label == 'Hook script (Task, PreToolUse)');
      expect(task.ok, isFalse);
      expect(task.hint, contains('flart init --global'));
    });

    test('claude binary missing → version probe shows ✗ with hint', () async {
      final checker = HookChecker(
        whichExe: (exe) async => '/fake/$exe',
        detectVersion: () async => null,
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
      );
      final claude = results.firstWhere((r) => r.label == 'Claude Code');
      expect(claude.ok, isFalse);
      expect(claude.detail, contains('version unknown'));
      expect(claude.hint, contains('Install Claude Code'));
    });

    test('rendered table shows ✓/✗ with hint indentation', () async {
      final checker = HookChecker(
        whichExe: (exe) async => exe == 'flart' ? '/usr/local/bin/flart' : null,
        detectVersion: () async => const ClaudeCodeVersion(2, 1, 144),
      );
      final results = await checker.diagnose(
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
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
