import 'runner.dart';

/// v0.2.0 — adds the `subagent_activations` table for tracking Claude Code
/// sub-agent spawn events (PreToolUse / Task hook). Kept separate from the
/// `invocations` table because activations have no measurable byte/token
/// savings — they're a pure activation counter.
class MigrationV2 implements Migration {
  const MigrationV2();

  @override
  int get version => 2;

  @override
  List<String> get statements => const [
        '''
        CREATE TABLE subagent_activations (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp         INTEGER NOT NULL,
          project_path      TEXT NOT NULL,
          parent_session_id TEXT
        )
        ''',
        'CREATE INDEX idx_subagent_timestamp ON subagent_activations(timestamp DESC)',
        'CREATE INDEX idx_subagent_project ON subagent_activations(project_path, timestamp DESC)',
      ];
}
