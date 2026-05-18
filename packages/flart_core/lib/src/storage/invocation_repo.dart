import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

/// One row in the `invocations` table. Constructed by callers (e.g.
/// [InvocationTracker]) and persisted via [InvocationRepo.insert]. Returned
/// rows fill [id] and [timestamp] from the database.
@immutable
class InvocationRecord {
  final int? id;
  final DateTime timestamp;
  final String projectPath;
  final String module;
  final String command;
  final String? args;
  final int rawBytes;
  final int filteredBytes;
  final int rawChars;
  final int filteredChars;
  final int estRawTokens;
  final int estFiltTokens;
  final int durationMs;
  final int exitCode;
  final bool wasTruncated;
  final String? teePath;

  /// Decoded JSON object stored in `metadata_json`. `null` when the column
  /// is NULL; an empty map when the column is `'{}'`. List-shaped JSON is
  /// rejected — the schema requires an object payload.
  final Map<String, Object?>? metadata;

  const InvocationRecord({
    this.id,
    required this.timestamp,
    required this.projectPath,
    required this.module,
    required this.command,
    this.args,
    required this.rawBytes,
    required this.filteredBytes,
    required this.rawChars,
    required this.filteredChars,
    required this.estRawTokens,
    required this.estFiltTokens,
    required this.durationMs,
    required this.exitCode,
    this.wasTruncated = false,
    this.teePath,
    this.metadata,
  });

  factory InvocationRecord.fromRow(Row row) {
    final metaRaw = row['metadata_json'] as String?;
    Map<String, Object?>? meta;
    if (metaRaw != null && metaRaw.isNotEmpty) {
      final decoded = jsonDecode(metaRaw);
      if (decoded is Map) {
        meta = decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return InvocationRecord(
      id: row['id'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (row['timestamp'] as int) * 1000,
        isUtc: true,
      ),
      projectPath: row['project_path'] as String,
      module: row['module'] as String,
      command: row['command'] as String,
      args: row['args'] as String?,
      rawBytes: row['raw_bytes'] as int,
      filteredBytes: row['filtered_bytes'] as int,
      rawChars: row['raw_chars'] as int,
      filteredChars: row['filtered_chars'] as int,
      estRawTokens: row['est_raw_tokens'] as int,
      estFiltTokens: row['est_filt_tokens'] as int,
      durationMs: row['duration_ms'] as int,
      exitCode: row['exit_code'] as int,
      wasTruncated: (row['was_truncated'] as int) != 0,
      teePath: row['tee_path'] as String?,
      metadata: meta,
    );
  }
}

/// CRUD wrapper around the `invocations` table.
class InvocationRepo {
  final FlartDatabase db;

  InvocationRepo(this.db);

  /// Inserts [r] and returns the new row's primary key.
  int insert(InvocationRecord r) {
    db.raw.execute(
      '''
      INSERT INTO invocations (
        timestamp, project_path, module, command, args,
        raw_bytes, filtered_bytes, raw_chars, filtered_chars,
        est_raw_tokens, est_filt_tokens, duration_ms, exit_code,
        was_truncated, tee_path, metadata_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        r.timestamp.millisecondsSinceEpoch ~/ 1000,
        r.projectPath,
        r.module,
        r.command,
        r.args,
        r.rawBytes,
        r.filteredBytes,
        r.rawChars,
        r.filteredChars,
        r.estRawTokens,
        r.estFiltTokens,
        r.durationMs,
        r.exitCode,
        r.wasTruncated ? 1 : 0,
        r.teePath,
        r.metadata == null ? null : jsonEncode(r.metadata),
      ],
    );
    return db.raw.lastInsertRowId;
  }

  /// Reads rows matching the filters, ordered by timestamp DESC.
  ///
  /// All filters are optional and combine with `AND`. [since] is inclusive,
  /// [until] is exclusive.
  List<InvocationRecord> findRange({
    DateTime? since,
    DateTime? until,
    String? projectPath,
    String? command,
    String? module,
    int? limit,
  }) {
    final where = <String>[];
    final params = <Object?>[];
    if (since != null) {
      where.add('timestamp >= ?');
      params.add(since.millisecondsSinceEpoch ~/ 1000);
    }
    if (until != null) {
      where.add('timestamp < ?');
      params.add(until.millisecondsSinceEpoch ~/ 1000);
    }
    if (projectPath != null) {
      where.add('project_path = ?');
      params.add(projectPath);
    }
    if (command != null) {
      where.add('command = ?');
      params.add(command);
    }
    if (module != null) {
      where.add('module = ?');
      params.add(module);
    }

    final buf = StringBuffer('SELECT * FROM invocations');
    if (where.isNotEmpty) buf.write(' WHERE ${where.join(' AND ')}');
    buf.write(' ORDER BY timestamp DESC');
    if (limit != null) {
      buf.write(' LIMIT ?');
      params.add(limit);
    }
    return db.raw
        .select(buf.toString(), params)
        .map(InvocationRecord.fromRow)
        .toList();
  }

  int count() {
    final row = db.raw.select('SELECT COUNT(*) AS c FROM invocations').first;
    return row['c'] as int;
  }
}
