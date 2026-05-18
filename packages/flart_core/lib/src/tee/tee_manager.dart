import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/config.dart';

/// Persists raw command output to disk for later inspection, with config-driven
/// gating and rotation. See Plan Section 3.6.
class TeeManager {
  final TeeConfig config;

  /// Resolved tee directory — caller passes either `config.directory` or the
  /// computed default (typically `<dataDir>/tee`). Never `null`.
  final String teeDirectory;
  final DateTime Function() _now;

  TeeManager({
    required this.config,
    required this.teeDirectory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Whether a tee should be written for a process with the given [exitCode].
  /// Combines `tee.enabled` with `tee.mode`.
  bool shouldTee(int exitCode) {
    if (!config.enabled) return false;
    switch (config.mode) {
      case TeeMode.never:
        return false;
      case TeeMode.always:
        return true;
      case TeeMode.failures:
        return exitCode != 0;
    }
  }

  /// Writes [content] to `<teeDirectory>/<epoch>_<slug>.log` and returns the
  /// file path. Returns `null` when [content] is smaller than
  /// `tee.min_size_bytes` (avoids creating noise files for tiny outputs).
  ///
  /// After writing, enforces `tee.max_files` by deleting the oldest entries.
  Future<String?> write(String slug, String content) async {
    final bytes = utf8.encode(content);
    if (bytes.length < config.minSizeBytes) return null;

    final dir = Directory(teeDirectory);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final epoch = _now().millisecondsSinceEpoch ~/ 1000;
    final safeSlug = _sanitize(slug);
    final filename = '${epoch}_$safeSlug.log';
    final filePath = p.join(teeDirectory, filename);
    await File(filePath).writeAsBytes(bytes, flush: true);

    _enforceRotation();
    return filePath;
  }

  /// Trims the tee directory down to `config.max_files` entries by deleting
  /// the oldest files. Silent on individual delete failures (best-effort).
  void _enforceRotation() {
    final dir = Directory(teeDirectory);
    if (!dir.existsSync()) return;
    final logs = dir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => p.basename(f.path).endsWith('.log'))
        .toList();
    if (logs.length <= config.maxFiles) return;

    logs.sort((a, b) {
      final am = a.statSync().modified;
      final bm = b.statSync().modified;
      final cmp = am.compareTo(bm);
      // Fall back to path order for files written within the same second.
      return cmp != 0 ? cmp : a.path.compareTo(b.path);
    });
    final toDelete = logs.take(logs.length - config.maxFiles);
    for (final f in toDelete) {
      try {
        f.deleteSync();
      } on FileSystemException {
        // Best-effort rotation; skip and continue.
      }
    }
  }

  /// Filename-safe slug: keeps alnum/underscore/hyphen, replaces the rest
  /// with `_`. Caps at 64 chars to keep paths reasonable.
  static String _sanitize(String slug) {
    final cleaned = slug.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.length <= 64 ? cleaned : cleaned.substring(0, 64);
  }
}
