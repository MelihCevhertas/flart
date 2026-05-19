import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

/// One row in the `subagent_activations` table. Recorded by the PreToolUse /
/// Task hook every time the parent agent spawns a sub-agent via the Task
/// tool. Has no byte/token columns — sub-agent context injection has no
/// measurable raw/filtered output savings; we only track that the hook fired.
@immutable
class SubagentActivation {
  final int? id;
  final DateTime timestamp;
  final String projectPath;
  final String? parentSessionId;

  const SubagentActivation({
    this.id,
    required this.timestamp,
    required this.projectPath,
    this.parentSessionId,
  });

  factory SubagentActivation.fromRow(Row row) => SubagentActivation(
        id: row['id'] as int,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (row['timestamp'] as int) * 1000,
          isUtc: true,
        ),
        projectPath: row['project_path'] as String,
        parentSessionId: row['parent_session_id'] as String?,
      );
}

/// CRUD wrapper around the `subagent_activations` table.
class SubagentActivationRepo {
  final FlartDatabase db;

  SubagentActivationRepo(this.db);

  /// Inserts [a] and returns the new row's primary key.
  int insert(SubagentActivation a) {
    db.raw.execute(
      '''
      INSERT INTO subagent_activations (
        timestamp, project_path, parent_session_id
      ) VALUES (?, ?, ?)
      ''',
      [
        a.timestamp.millisecondsSinceEpoch ~/ 1000,
        a.projectPath,
        a.parentSessionId,
      ],
    );
    return db.raw.lastInsertRowId;
  }

  /// Count of activations matching the optional filters. All filters AND
  /// together; [since] is inclusive, [until] is exclusive.
  int count({
    DateTime? since,
    DateTime? until,
    String? projectPath,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    if (since != null) {
      where.add('timestamp >= ?');
      params.add(since.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (until != null) {
      where.add('timestamp < ?');
      params.add(until.toUtc().millisecondsSinceEpoch ~/ 1000);
    }
    if (projectPath != null) {
      where.add('project_path = ?');
      params.add(projectPath);
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final row = db.raw
        .select('SELECT COUNT(*) AS c FROM subagent_activations $whereClause',
            params)
        .first;
    return row['c'] as int;
  }

  /// Recent N activations ordered by timestamp DESC.
  List<SubagentActivation> recent({
    int limit = 20,
    String? projectPath,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    if (projectPath != null) {
      where.add('project_path = ?');
      params.add(projectPath);
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    params.add(limit);
    return db.raw
        .select(
          'SELECT * FROM subagent_activations $whereClause '
          'ORDER BY timestamp DESC LIMIT ?',
          params,
        )
        .map(SubagentActivation.fromRow)
        .toList();
  }
}
