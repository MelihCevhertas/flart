/// Parses the `--since` (and friends) flag values.
///
/// Accepts:
/// - Relative: `<N><unit>` where unit ∈ `{h, d, w, m}` (e.g. `7d`, `24h`,
///   `2w`, `3m` for 3 × 30 days).
/// - Absolute: an ISO-8601 date or datetime string (e.g. `2026-01-01`,
///   `2026-05-18T12:30:00Z`).
///
/// Returns `null` when [raw] is null or empty. Throws [FormatException]
/// on unparseable strings so the CLI can surface a usage error.
DateTime? parseSince(String? raw, {DateTime Function()? now}) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  final nowFn = now ?? DateTime.now;

  // Relative form.
  final rel = RegExp(r'^(\d+)([hdwm])$').firstMatch(s);
  if (rel != null) {
    final n = int.parse(rel.group(1)!);
    final unit = rel.group(2)!;
    final base = nowFn();
    switch (unit) {
      case 'h':
        return base.subtract(Duration(hours: n));
      case 'd':
        return base.subtract(Duration(days: n));
      case 'w':
        return base.subtract(Duration(days: n * 7));
      case 'm':
        return base.subtract(Duration(days: n * 30));
    }
  }

  // Absolute form — date-only strings are treated as UTC midnight (matches
  // how users intuitively write `--since 2026-01-15`); datetimes with an
  // explicit Z/offset are honored as-is and converted to UTC for storage.
  final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
  if (dateOnly) {
    return DateTime.parse('${s}T00:00:00Z');
  }
  return DateTime.parse(s).toUtc();
}
