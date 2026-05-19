/// flart_hooks — Claude Code integration: hook installer and rewrite logic.
library;

export 'src/installer.dart'
    show
        CheckResult,
        HookChecker,
        HookInstaller,
        ProjectInstaller,
        atomicWriteString,
        defaultClaudeSettingsPath,
        defaultHookScriptPath,
        defaultTaskHookScriptPath,
        renderCheckTable,
        resolveConfigHome;
export 'src/rewriter.dart' show CommandRewriter;
export 'src/templates/claude_md_block.dart'
    show claudeMdBlock, claudeMdMarkerEnd, claudeMdMarkerStart;
export 'src/templates/rewrite_sh.dart' show hookScriptTemplate;
export 'src/templates/task_context.dart' show taskAdditionalContext;
export 'src/templates/task_hook_sh.dart' show taskHookScriptTemplate;
