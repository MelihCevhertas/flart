import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flart_core/flart_core.dart';
import 'package:flart_filters/flart_filters.dart';
import 'package:path/path.dart' as p;

import '../filter_runner.dart';

/// Shared scaffolding for every `flart <subcommand>` that wraps a
/// [CommandFilter]. Concrete commands supply the filter and (optionally)
/// override metadata; the base handles composition root + I/O injection.
abstract class FilterCommandBase extends Command<int> {
  final FlartEnv? envOverride;
  final IOSink? stdoutOverride;
  final IOSink? stderrOverride;

  FilterCommandBase({
    this.envOverride,
    this.stdoutOverride,
    this.stderrOverride,
  });

  /// Filter commands pass through any flags the underlying `dart`/`flutter`
  /// tool accepts (e.g. `--fatal-infos`, `--output=none`, `--line-length=80`).
  /// We don't enumerate them — args package's `allowAnything` makes the
  /// parser accept everything; we read it back via `argResults!.arguments`.
  @override
  ArgParser get argParser => ArgParser.allowAnything();

  /// The filter to run for this subcommand. Concrete commands consume only
  /// what they need from [config] (e.g. `filters.truncate_long_messages_at`).
  CommandFilter buildFilter(ProjectContext project, Config config);

  @override
  Future<int> run() async {
    // With `ArgParser.allowAnything()`, every arg lands in `arguments`
    // (`rest` would always be empty). Pass them verbatim to the native tool.
    final userArgs = argResults?.arguments.toList() ?? const <String>[];
    final env = envOverride ?? FlartEnv.fromPlatform();
    final config = Config.defaults();
    final project = ProjectContext.detect();
    final dataDir = env.dataDir ?? _defaultDataDir(env);
    final dbPath = p.join(dataDir, 'savings.db');
    Directory(p.dirname(dbPath)).createSync(recursive: true);

    final db = FlartDatabase.open(path: dbPath);
    try {
      final repo = InvocationRepo(db);
      final estimator = TokenEstimator.fromConfig(config);
      final tracker = InvocationTracker(
        repo: repo,
        estimator: estimator,
        project: project,
        env: env,
      );
      final tee = TeeManager(
        config: config.tee,
        teeDirectory: config.tee.directory ?? p.join(dataDir, 'tee'),
      );
      final runner = FilterRunner(
        filter: buildFilter(project, config),
        tracker: tracker,
        tee: tee,
        stdoutSink: stdoutOverride,
        stderrSink: stderrOverride,
      );
      return await runner.run(userArgs);
    } finally {
      db.dispose();
    }
  }

  static String _defaultDataDir(FlartEnv env) {
    final home = env.home;
    if (home == null) return Directory.systemTemp.path;
    return p.join(home, '.local', 'share', 'flart');
  }
}
