import 'filter.dart';
import 'filter_result.dart';

/// `flart pub upgrade` — wraps `flutter pub upgrade` / `dart pub upgrade`.
/// Plan 5.4.4 (target band 70-85%).
///
/// Output shapes from real Dart 3.11:
/// ```
/// Resolving dependencies...
/// Downloading packages...
/// > pkg 1.0.0 (1.1.0 available)     # informational
/// ~ pkg 1.0.0 → 1.1.0               # upgraded
/// Changed N dependencies!           # changes summary
/// No dependencies changed.          # no-change summary
/// ```
///
/// Compact output mirrors [PubGetFilter] but emphasises which packages were
/// upgraded (which is the agent's real question on `pub upgrade`).
class PubUpgradeFilter implements CommandFilter {
  final bool isFlutterProject;

  PubUpgradeFilter({this.isFlutterProject = true});

  @override
  String get name => 'pub_upgrade';

  @override
  String get flartCommand => 'pub';

  @override
  List<String> baseNativeCommand(List<String> userArgs) => isFlutterProject
      ? const ['flutter', 'pub', 'upgrade']
      : const ['dart', 'pub', 'upgrade'];

  @override
  Map<String, String> environment(List<String> userArgs) => const {};

  @override
  FilterResult filter({
    required String stdout,
    required String stderr,
    required int exitCode,
    required List<String> userArgs,
  }) {
    final upgrades = <String>[];
    final additions = <String>[];
    final removals = <String>[];
    bool noneChanged = false;
    String? errorBlock;
    bool sawSuccessSummary = false;

    for (final raw in stdout.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('Resolving dependencies') ||
          line.startsWith('Downloading packages')) {
        continue;
      }
      if (line.startsWith('~ ')) {
        upgrades.add(line);
        continue;
      }
      if (line.startsWith('+ ')) {
        additions.add(line);
        continue;
      }
      if (line.startsWith('- ')) {
        removals.add(line);
        continue;
      }
      if (line.startsWith('> ')) {
        // "> pkg X (Y available)" — informational, drop.
        continue;
      }
      if (line.startsWith('No dependencies changed')) {
        noneChanged = true;
        sawSuccessSummary = true;
        continue;
      }
      if (line.startsWith('Changed ') && line.contains('dependencies')) {
        sawSuccessSummary = true;
        continue;
      }
      if (exitCode != 0 || !sawSuccessSummary) {
        errorBlock = errorBlock == null ? line : '$errorBlock\n$line';
      }
    }

    final totalChanges = upgrades.length + additions.length + removals.length;
    final metadata = <String, Object?>{
      'upgraded': upgrades.length,
      'added': additions.length,
      'removed': removals.length,
      'none_changed': noneChanged,
      'failed': exitCode != 0,
    };

    if (exitCode != 0) {
      final hint = (errorBlock?.trim().isNotEmpty ?? false)
          ? errorBlock!.trim()
          : (stderr.trim().isEmpty
              ? 'see full output (exit $exitCode)'
              : stderr.trim());
      return FilterResult(
        output: 'FAILED: pub upgrade (exit $exitCode)\n$hint',
        metadata: metadata,
      );
    }

    if (totalChanges == 0) {
      return FilterResult(
        output: 'no upgrades available',
        metadata: metadata,
      );
    }

    final buf =
        StringBuffer('upgraded $totalChanges dependencies')..writeln();
    for (final u in upgrades) {
      buf.writeln('  $u');
    }
    for (final a in additions) {
      buf.writeln('  $a');
    }
    for (final r in removals) {
      buf.writeln('  $r');
    }
    return FilterResult(
      output: buf.toString().trimRight(),
      metadata: metadata,
    );
  }
}
