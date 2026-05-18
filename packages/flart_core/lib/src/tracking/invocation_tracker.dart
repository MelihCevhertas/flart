import 'dart:convert';

import '../env.dart';
import '../project_context.dart';
import '../storage/invocation_repo.dart';
import '../tokens/estimator.dart';

/// High-level recording API used by filter runners and the sandbox executor.
///
/// Computes byte/char/token counts from raw + filtered text, fills in project
/// path and timestamp, and writes a single row to the `invocations` table.
/// Honors `FLART_NO_SAVINGS=1` — in that case [record] is a no-op and returns
/// `null`.
class InvocationTracker {
  final InvocationRepo repo;
  final TokenEstimator estimator;
  final ProjectContext project;
  final FlartEnv env;
  final DateTime Function() _now;

  InvocationTracker({
    required this.repo,
    required this.estimator,
    required this.project,
    required this.env,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Inserts a new invocation row.
  ///
  /// Returns the new row id, or `null` when `FLART_NO_SAVINGS` is set.
  Future<int?> record({
    required String module,
    required String command,
    String? args,
    required String rawText,
    required String filteredText,
    required int durationMs,
    required int exitCode,
    bool wasTruncated = false,
    String? teePath,
    Map<String, Object?> metadata = const {},
  }) async {
    if (env.noSavings) return null;

    final rawBytes = utf8.encode(rawText).length;
    final filteredBytes = utf8.encode(filteredText).length;

    final record = InvocationRecord(
      // Normalize to UTC so DB roundtrips are timezone-independent.
      timestamp: _now().toUtc(),
      projectPath: project.root,
      module: module,
      command: command,
      args: args,
      rawBytes: rawBytes,
      filteredBytes: filteredBytes,
      rawChars: rawText.length,
      filteredChars: filteredText.length,
      estRawTokens: estimator.estimate(rawText),
      estFiltTokens: estimator.estimate(filteredText),
      durationMs: durationMs,
      exitCode: exitCode,
      wasTruncated: wasTruncated,
      teePath: teePath,
      metadata: metadata.isEmpty ? null : metadata,
    );
    return repo.insert(record);
  }
}
