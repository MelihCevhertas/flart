import 'runner.dart';

/// Initial schema — frozen at v0 of the data model per Plan Section 16.4.
/// Future migrations may add columns but must not rename or drop existing ones.
class MigrationV1 implements Migration {
  const MigrationV1();

  @override
  int get version => 1;

  @override
  List<String> get statements => const [
        '''
        CREATE TABLE invocations (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp       INTEGER NOT NULL,
          project_path    TEXT NOT NULL,
          module          TEXT NOT NULL,
          command         TEXT NOT NULL,
          args            TEXT,
          raw_bytes       INTEGER NOT NULL,
          filtered_bytes  INTEGER NOT NULL,
          raw_chars       INTEGER NOT NULL,
          filtered_chars  INTEGER NOT NULL,
          est_raw_tokens  INTEGER NOT NULL,
          est_filt_tokens INTEGER NOT NULL,
          duration_ms     INTEGER NOT NULL,
          exit_code       INTEGER NOT NULL,
          was_truncated   INTEGER NOT NULL DEFAULT 0,
          tee_path        TEXT,
          metadata_json   TEXT
        )
        ''',
        'CREATE INDEX idx_invocations_timestamp ON invocations(timestamp DESC)',
        'CREATE INDEX idx_invocations_project ON invocations(project_path, timestamp DESC)',
        'CREATE INDEX idx_invocations_command ON invocations(command, timestamp DESC)',
      ];
}

/// All known migrations, in order. Appended to in future versions; never
/// reordered or rewritten.
const List<Migration> allMigrations = [MigrationV1()];
