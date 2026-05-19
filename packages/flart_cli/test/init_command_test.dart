// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_cli/commands/init_command.dart';
import 'package:flart_core/flart_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _CapturingSink implements IOSink {
  final StringBuffer buffer = StringBuffer();
  @override
  Encoding encoding = utf8;
  @override
  void write(Object? o) => buffer.write(o);
  @override
  void writeln([Object? o = '']) => buffer.writeln(o);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int c) => buffer.write(String.fromCharCode(c));
  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));
  @override
  void addError(Object e, [StackTrace? s]) {}
  @override
  Future<void> addStream(Stream<List<int>> s) async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> get done => Future.value();
}

Future<({int code, String stdout, String stderr})> _runInit(
  List<String> args, {
  required String settingsPath,
  required String hookScriptPath,
  required String taskHookScriptPath,
  required String claudeMdPath,
  Future<String?> Function(String)? whichExe,
  String? stdinReply,
}) async {
  final out = _CapturingSink();
  final err = _CapturingSink();
  final stdinSource = stdinReply == null
      ? const Stream<List<int>>.empty()
      : Stream<List<int>>.fromIterable([utf8.encode('$stdinReply\n')]);
  final cmd = InitCommand(
    envOverride: FlartEnv({'HOME': Directory.systemTemp.path}),
    stdoutOverride: out,
    stderrOverride: err,
    stdinOverride: stdinSource,
    settingsPathOverride: settingsPath,
    hookScriptPathOverride: hookScriptPath,
    taskHookScriptPathOverride: taskHookScriptPath,
    claudeMdPathOverride: claudeMdPath,
    whichExeOverride: whichExe ?? (exe) async => '/fake/$exe',
  );
  final runner = CommandRunner<int>('flart-test', 'init test runner')
    ..addCommand(cmd);
  final code = await runner.run(args);
  return (
    code: code ?? 0,
    stdout: out.buffer.toString(),
    stderr: err.buffer.toString(),
  );
}

void main() {
  late Directory tmp;
  late String settingsPath;
  late String hookScriptPath;
  late String taskHookScriptPath;
  late String claudeMdPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('flart_init_cmd_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    settingsPath = p.join(tmp.path, '.claude', 'settings.json');
    hookScriptPath =
        p.join(tmp.path, '.config', 'flart', 'hooks', 'rewrite.sh');
    taskHookScriptPath =
        p.join(tmp.path, '.config', 'flart', 'hooks', 'task_hook.sh');
    claudeMdPath = p.join(tmp.path, 'project', 'CLAUDE.md');
  });

  group('flart init --yes (install)', () {
    test('installs hook script + settings entry + CLAUDE.md block', () async {
      final r = await _runInit(
        ['init', '--yes'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      expect(r.code, 0);
      expect(File(hookScriptPath).existsSync(), isTrue);
      expect(File(taskHookScriptPath).existsSync(), isTrue);
      expect(File(settingsPath).existsSync(), isTrue);
      expect(File(claudeMdPath).existsSync(), isTrue);
      final settings = jsonDecode(File(settingsPath).readAsStringSync()) as Map;
      final hooks = (settings['hooks'] as Map)['PreToolUse'] as List;
      // v0.2.0: PreToolUse now has both Bash (rewrite.sh) and Task (task_hook.sh).
      expect(hooks.length, 2);
      expect(hooks.map((e) => (e as Map)['matcher']), containsAll(['Bash', 'Task']));
      final claudeContent = File(claudeMdPath).readAsStringSync();
      expect(claudeContent, contains('flart routing'));
    });

    test('confirmation prompt: "n" → no changes', () async {
      final r = await _runInit(
        ['init'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
        stdinReply: 'n',
      );
      expect(r.code, 0);
      expect(r.stdout, contains('Cancelled'));
      expect(File(hookScriptPath).existsSync(), isFalse);
      expect(File(settingsPath).existsSync(), isFalse);
    });

    test('confirmation prompt: "y" → installs', () async {
      final r = await _runInit(
        ['init'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
        stdinReply: 'y',
      );
      expect(r.code, 0);
      expect(File(hookScriptPath).existsSync(), isTrue);
    });
  });

  group('flart init --global / --project scope flags', () {
    test('--global writes hook + settings only', () async {
      final r = await _runInit(
        ['init', '--global', '--yes'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      expect(r.code, 0);
      expect(File(hookScriptPath).existsSync(), isTrue);
      expect(File(taskHookScriptPath).existsSync(), isTrue);
      expect(File(claudeMdPath).existsSync(), isFalse);
    });

    test('--project writes CLAUDE.md only', () async {
      final r = await _runInit(
        ['init', '--project', '--yes'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      expect(r.code, 0);
      expect(File(hookScriptPath).existsSync(), isFalse);
      expect(File(taskHookScriptPath).existsSync(), isFalse);
      expect(File(claudeMdPath).existsSync(), isTrue);
    });
  });

  group('flart init --show', () {
    test('reports missing state before install', () async {
      final r = await _runInit(
        ['init', '--show'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      expect(r.code, 0);
      expect(r.stdout, contains('not installed'));
    });

    test('reports installed state after install', () async {
      await _runInit(
        ['init', '--yes'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      final r = await _runInit(
        ['init', '--show'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      expect(r.code, 0);
      expect(r.stdout, contains('✓'));
      expect(r.stdout, contains(hookScriptPath));
    });
  });

  group('flart init --check', () {
    test('exit 1 when jq missing', () async {
      await _runInit(
        ['init', '--yes'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      final r = await _runInit(
        ['init', '--check'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
        whichExe: (exe) async => exe == 'jq' ? null : '/fake/$exe',
      );
      expect(r.code, 1);
      expect(r.stdout, contains('✗ jq'));
      expect(r.stdout, contains('brew install jq'));
    });

    test('exit 0 when everything is installed', () async {
      await _runInit(
        ['init', '--yes'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      final r = await _runInit(
        ['init', '--check'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      expect(r.code, 0);
      expect(r.stdout, isNot(contains('✗')));
    });
  });

  group('flart init --uninstall', () {
    test('removes integration but reminds about savings DB', () async {
      await _runInit(
        ['init', '--yes'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      // Plant a fake savings.db in the same parent — must remain untouched.
      final fakeSavings = File(p.join(tmp.path, 'savings.db'));
      fakeSavings.writeAsStringSync('not really a db');

      final r = await _runInit(
        ['init', '--uninstall'],
        settingsPath: settingsPath,
        hookScriptPath: hookScriptPath,
        taskHookScriptPath: taskHookScriptPath,
        claudeMdPath: claudeMdPath,
      );
      expect(r.code, 0);
      expect(File(hookScriptPath).existsSync(), isFalse);
      expect(File(taskHookScriptPath).existsSync(), isFalse);
      // CLAUDE.md only had the routing block → file gets deleted.
      expect(File(claudeMdPath).existsSync(), isFalse);
      expect(fakeSavings.existsSync(), isTrue,
          reason: 'uninstall must NOT touch savings DB');
      expect(r.stdout, contains('Savings DB was not touched'));
    });
  });
}
