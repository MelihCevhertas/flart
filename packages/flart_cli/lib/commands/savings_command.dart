import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_savings/flart_savings.dart';
import 'package:path/path.dart' as p;

/// `flart savings` — Plan Section 6.2. Read-only report over the savings DB.
class SavingsCommand extends Command<int> {
  final FlartEnv? _envOverride;
  final IOSink? _stdoutOverride;
  final IOSink? _stderrOverride;
  final Stream<List<int>>? _stdinOverride;

  SavingsCommand({
    FlartEnv? envOverride,
    IOSink? stdoutOverride,
    IOSink? stderrOverride,
    Stream<List<int>>? stdinOverride,
  })  : _envOverride = envOverride,
        _stdoutOverride = stdoutOverride,
        _stderrOverride = stderrOverride,
        _stdinOverride = stdinOverride {
    argParser
      ..addOption('since',
          help: 'Relative (7d/24h/2w/3m) or ISO-8601 absolute timestamp.')
      ..addOption('until',
          help: 'Upper bound (exclusive). Same format as --since.')
      ..addFlag('project',
          negatable: false,
          help: 'Limit to the current project (detected from cwd).')
      ..addFlag('by-command',
          negatable: false,
          help: 'Group by flart subcommand.')
      ..addFlag('by-module',
          negatable: false,
          help: 'Group by module (filter | executor).')
      ..addOption('top',
          help: 'Show top N invocations by tokens saved.')
      ..addFlag('details',
          negatable: false,
          help: 'List the most recent invocations in detail.')
      ..addOption('limit',
          defaultsTo: '20',
          help: 'Limit for --top / --details.')
      ..addFlag('json', negatable: false, help: 'Emit JSON.')
      ..addFlag('csv', negatable: false, help: 'Emit CSV.')
      ..addFlag('graph',
          negatable: false,
          help: 'Render an ASCII chart of tokens saved per day.')
      ..addFlag('reset',
          negatable: false,
          help: 'Delete every invocation row (requires confirmation).')
      ..addFlag('force',
          negatable: false,
          help: 'Skip --reset confirmation (CI use).');
  }

  @override
  String get name => 'savings';

  @override
  String get description => 'Show the flart savings report.';

  @override
  String get invocation => 'flart savings [flags...]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final out = _stdoutOverride ?? stdout;
    final err = _stderrOverride ?? stderr;

    final env = _envOverride ?? FlartEnv.fromPlatform();
    final config = Config.defaults();
    final dataDir = env.dataDir ?? _defaultDataDir(env);
    final dbPath = p.join(dataDir, 'savings.db');

    if (!File(dbPath).existsSync()) {
      out.writeln(
          'No savings database yet. Run flart commands to populate $dbPath.');
      return 0;
    }

    final db = FlartDatabase.open(path: dbPath);
    try {
      if (results['reset'] as bool) {
        return await _handleReset(
          db,
          force: results['force'] as bool,
          out: out,
          err: err,
        );
      }

      final DateTime? since;
      final DateTime? until;
      try {
        since = parseSince(results['since'] as String?);
        until = parseSince(results['until'] as String?);
      } on FormatException catch (e) {
        err.writeln('flart savings: invalid timestamp — ${e.message}');
        return 100;
      }

      String? projectPath;
      if (results['project'] as bool) {
        projectPath = ProjectContext.detect().root;
      }

      final agg = Aggregator(db);
      final summary = agg.summary(
        since: since,
        until: until,
        projectPath: projectPath,
      );

      if (results['json'] as bool) {
        final body = JsonFormatter().render(
          summary: summary,
          byModule: agg.byModule(
              since: since, until: until, projectPath: projectPath),
          byProject: agg.byProject(since: since, until: until),
          topCommands: agg.byCommand(
              since: since, until: until, projectPath: projectPath),
        );
        out.writeln(body);
        return 0;
      }
      if (results['csv'] as bool) {
        final body = CsvFormatter().render(
          byModule: agg.byModule(
              since: since, until: until, projectPath: projectPath),
          byCommand: agg.byCommand(
              since: since, until: until, projectPath: projectPath),
          byProject: agg.byProject(since: since, until: until),
        );
        out.write(body);
        return 0;
      }
      if (results['graph'] as bool) {
        final buckets = agg.dailyBuckets(days: 30);
        out.writeln(GraphFormatter().render(buckets));
        return 0;
      }

      final limit = int.tryParse(results['limit'] as String) ?? 20;
      final text = TextFormatter(
        charsPerToken: config.tokenEstimation.charsPerToken,
        estimatedDeviation: config.tokenEstimation.estimatedDeviation,
      );

      // Single-purpose group views.
      if (results['by-command'] as bool) {
        final rows = agg.byCommand(
            since: since, until: until, projectPath: projectPath);
        out.writeln(text.renderByCommand(rows));
        return 0;
      }
      if (results['by-module'] as bool) {
        final rows = agg.byModule(
            since: since, until: until, projectPath: projectPath);
        out.writeln(text.renderByCommand(rows)); // same shape: label/calls/tokens
        return 0;
      }
      if (results['top'] != null) {
        final topLimit = int.tryParse(results['top'] as String) ?? 10;
        final tops = agg.top(
          limit: topLimit,
          since: since,
          until: until,
          projectPath: projectPath,
        );
        out.writeln(text.renderTopInvocations(tops, limit: topLimit));
        return 0;
      }
      if (results['details'] as bool) {
        final rows = agg.details(
          limit: limit,
          since: since,
          until: until,
          projectPath: projectPath,
        );
        out.writeln(text.renderDetails(rows));
        return 0;
      }

      // Default: full report.
      final body = text.render(
        summary: summary,
        byModule: agg.byModule(
            since: since, until: until, projectPath: projectPath),
        byProject: agg.byProject(since: since, until: until),
        topCommands: agg.byCommand(
            since: since, until: until, projectPath: projectPath),
      );
      out.writeln(body);
      return 0;
    } finally {
      db.dispose();
    }
  }

  Future<int> _handleReset(
    FlartDatabase db, {
    required bool force,
    required IOSink out,
    required IOSink err,
  }) async {
    final agg = Aggregator(db);
    final summary = agg.summary();
    if (summary.invocations == 0) {
      out.writeln('No invocations to delete. Nothing to do.');
      return 0;
    }
    if (!force) {
      final oldest =
          summary.oldest?.toIso8601String().substring(0, 10) ?? 'unknown';
      out.write(
        'This will delete ALL flart savings data (${summary.invocations} '
        'invocations from $oldest to now). Continue? [y/N] ',
      );
      final source = _stdinOverride ?? stdin;
      final ans = await _readLine(source);
      final normalized = ans.trim().toLowerCase();
      if (normalized != 'y' && normalized != 'yes') {
        out.writeln('Cancelled. No changes made.');
        return 0;
      }
    }
    db.raw.execute('DELETE FROM invocations');
    out.writeln('Deleted ${summary.invocations} invocations.');
    return 0;
  }

  Future<String> _readLine(Stream<List<int>> source) async {
    final bytes = <int>[];
    await for (final chunk in source) {
      for (final b in chunk) {
        if (b == 0x0A) {
          // newline → done
          return String.fromCharCodes(bytes);
        }
        bytes.add(b);
      }
    }
    return String.fromCharCodes(bytes);
  }

  static String _defaultDataDir(FlartEnv env) {
    final home = env.home;
    if (home == null) return Directory.systemTemp.path;
    return p.join(home, '.local', 'share', 'flart');
  }
}
