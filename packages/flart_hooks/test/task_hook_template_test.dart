// ignore_for_file: depend_on_referenced_packages

import 'package:flart_hooks/flart_hooks.dart';
import 'package:test/test.dart';

void main() {
  group('taskHookScriptTemplate', () {
    test('starts with bash shebang and exits silently when flart missing', () {
      expect(taskHookScriptTemplate, startsWith('#!/usr/bin/env bash'));
      expect(taskHookScriptTemplate,
          contains('command -v flart >/dev/null 2>&1'));
      expect(taskHookScriptTemplate, contains('exec flart task-hook'));
    });

    test('does not depend on jq (Task path is pure dart)', () {
      // Bash hook needs jq for JSON merging; Task hook delegates everything
      // to `flart task-hook`, so jq must not be a hard dependency here.
      expect(taskHookScriptTemplate, isNot(contains('jq')));
    });
  });

  group('taskAdditionalContext', () {
    test('mentions flart and key subcommands so sub-agents pick them up', () {
      expect(taskAdditionalContext, contains('flart'));
      expect(taskAdditionalContext, contains('flart analyze'));
      expect(taskAdditionalContext, contains('flart test'));
      expect(taskAdditionalContext, contains('flart exec'));
    });

    test('stays compact (~ <500 chars to keep sub-agent context light)', () {
      expect(taskAdditionalContext.length, lessThan(500));
    });
  });
}
