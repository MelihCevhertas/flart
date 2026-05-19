import 'dart:io';

import 'package:meta/meta.dart';

/// Semantic version triple for Claude Code, parsed from `claude --version`.
/// Comparison is field-by-field (major, then minor, then patch).
@immutable
class ClaudeCodeVersion implements Comparable<ClaudeCodeVersion> {
  final int major;
  final int minor;
  final int patch;

  const ClaudeCodeVersion(this.major, this.minor, this.patch);

  /// First Claude Code release that supports `hookSpecificOutput.updatedToolOutput`
  /// in PostToolUse hooks. flart_hooks gates the PostToolUse / Bash entry on
  /// this — older Claude Codes would receive the JSON but silently ignore the
  /// `updatedToolOutput` field, leaving the agent with raw bash output.
  static const ClaudeCodeVersion outputMutationMinimum =
      ClaudeCodeVersion(2, 1, 121);

  bool get supportsOutputMutation => this >= outputMutationMinimum;

  @override
  int compareTo(ClaudeCodeVersion other) {
    final m = major.compareTo(other.major);
    if (m != 0) return m;
    final n = minor.compareTo(other.minor);
    if (n != 0) return n;
    return patch.compareTo(other.patch);
  }

  bool operator >=(ClaudeCodeVersion other) => compareTo(other) >= 0;
  bool operator >(ClaudeCodeVersion other) => compareTo(other) > 0;
  bool operator <=(ClaudeCodeVersion other) => compareTo(other) <= 0;
  bool operator <(ClaudeCodeVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is ClaudeCodeVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Greedy regex: first `<n>.<n>.<n>` triple wins. Tolerates surrounding
/// noise like `Claude Code v2.1.144 (build abc)` or just `2.1.144`. Returns
/// `null` when no triple is found.
final RegExp _versionTriple = RegExp(r'(\d+)\.(\d+)\.(\d+)');

ClaudeCodeVersion? parseClaudeVersion(String? raw) {
  if (raw == null) return null;
  final match = _versionTriple.firstMatch(raw);
  if (match == null) return null;
  return ClaudeCodeVersion(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Calls `claude --version` and parses the result. Returns `null` when the
/// `claude` binary is missing, exits non-zero, or its output doesn't contain
/// a recognisable semver triple. Best-effort: callers should treat `null` as
/// "version unknown" and degrade gracefully rather than fail.
///
/// [runVersion] is the injection seam — production passes the default that
/// shells out; tests pass a fake.
Future<ClaudeCodeVersion?> detectClaudeVersion({
  Future<String?> Function()? runVersion,
}) async {
  final out = await (runVersion ?? _defaultRunVersion)();
  return parseClaudeVersion(out);
}

Future<String?> _defaultRunVersion() async {
  try {
    final r = await Process.run('claude', const ['--version']);
    if (r.exitCode != 0) return null;
    final stdoutText = r.stdout is String ? r.stdout as String : '';
    final stderrText = r.stderr is String ? r.stderr as String : '';
    final combined = '$stdoutText\n$stderrText'.trim();
    return combined.isEmpty ? null : combined;
  } on ProcessException {
    return null;
  }
}
