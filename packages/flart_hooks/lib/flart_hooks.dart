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
        renderCheckTable,
        resolveConfigHome;
export 'src/rewriter.dart' show CommandRewriter;
export 'src/templates/claude_md_block.dart'
    show claudeMdBlock, claudeMdMarkerEnd, claudeMdMarkerStart;
export 'src/templates/rewrite_sh.dart' show hookScriptTemplate;
