import 'dart:convert';

/// Byte-safe string truncation that respects UTF-8 char boundaries and snaps
/// to line breaks. See Plan Section 3.5.
class SafeTruncator {
  /// Head + tail strategy: keep the first `headRatio` of [maxBytes] from the
  /// start and the rest from the end, with a marker in between describing
  /// what was removed. Snaps to line boundaries so partial log lines are
  /// avoided. Never splits a UTF-8 code point.
  ///
  /// [marker] placeholders (substituted after sizing is decided):
  ///   `{n}`     — number of newlines in the removed middle
  ///   `{bytes}` — UTF-8 bytes removed
  ///   `{head}`  — UTF-8 bytes kept in the head
  ///   `{tail}`  — UTF-8 bytes kept in the tail
  ///
  /// When [maxBytes] is too small to fit the marker, falls back to
  /// [byteSafePrefix] without a marker.
  static String headTail({
    required String input,
    required int maxBytes,
    double headRatio = 0.6,
    String marker =
        '\n... [{n} lines / {bytes} bytes truncated — kept first {head} + last {tail}] ...\n',
  }) {
    if (maxBytes <= 0) return '';
    final bytes = utf8.encode(input);
    if (bytes.length <= maxBytes) return input;

    // Worst-case marker size: substitute largest numbers we could plug in.
    final worstMarker = marker
        .replaceAll('{n}', bytes.length.toString())
        .replaceAll('{bytes}', bytes.length.toString())
        .replaceAll('{head}', maxBytes.toString())
        .replaceAll('{tail}', maxBytes.toString());
    final markerBudget = utf8.encode(worstMarker).length;

    final remaining = maxBytes - markerBudget;
    if (remaining <= 0) {
      // Marker bigger than what's left for content; degrade to plain prefix.
      return byteSafePrefix(input, maxBytes);
    }

    var headTarget = (remaining * headRatio).floor();
    var tailTarget = remaining - headTarget;
    if (headTarget < 1) headTarget = 1;
    if (tailTarget < 1) tailTarget = 1;

    final headEnd = _snapHeadToLine(bytes, headTarget);
    final tailStart =
        _snapTailToLine(bytes, bytes.length - tailTarget, headEnd);

    final headSlice = bytes.sublist(0, headEnd);
    final tailSlice = bytes.sublist(tailStart);
    final removedSlice = bytes.sublist(headEnd, tailStart);
    final removedLines = removedSlice.where((b) => b == 0x0A).length;
    final removedBytes = removedSlice.length;

    final finalMarker = marker
        .replaceAll('{n}', removedLines.toString())
        .replaceAll('{bytes}', removedBytes.toString())
        .replaceAll('{head}', headSlice.length.toString())
        .replaceAll('{tail}', tailSlice.length.toString());

    return utf8.decode(headSlice, allowMalformed: true) +
        finalMarker +
        utf8.decode(tailSlice, allowMalformed: true);
  }

  /// Returns the longest UTF-8 prefix of [input] that fits in [maxBytes].
  /// Never splits a multi-byte code point.
  static String byteSafePrefix(String input, int maxBytes) {
    if (maxBytes <= 0) return '';
    final bytes = utf8.encode(input);
    if (bytes.length <= maxBytes) return input;
    final cut = _backToCodePointStart(bytes, maxBytes);
    return utf8.decode(bytes.sublist(0, cut), allowMalformed: true);
  }

  /// Walks back from [desired] until landing on a non-continuation byte.
  /// Returns a length safe to slice at without splitting a UTF-8 sequence.
  static int _backToCodePointStart(List<int> bytes, int desired) {
    if (desired >= bytes.length) return bytes.length;
    var cut = desired;
    while (cut > 0 && (bytes[cut] & 0xC0) == 0x80) {
      cut--;
    }
    return cut;
  }

  /// Snap a head-of-string cut to the byte after the last newline at-or-before
  /// [target]. Falls back to a UTF-8 safe cut when no newline is found.
  static int _snapHeadToLine(List<int> bytes, int target) {
    final ceiling = _backToCodePointStart(bytes, target);
    for (var i = ceiling - 1; i >= 0; i--) {
      if (bytes[i] == 0x0A) return i + 1; // include the newline
    }
    return ceiling;
  }

  /// Snap a tail-of-string cut to the byte after the first newline at-or-after
  /// [target]. Result is never less than [minStart] (the head end).
  static int _snapTailToLine(List<int> bytes, int target, int minStart) {
    var start = target < minStart ? minStart : target;
    // First advance to next code-point start (avoid mid-sequence cut).
    while (start < bytes.length && (bytes[start] & 0xC0) == 0x80) {
      start++;
    }
    for (var i = start; i < bytes.length; i++) {
      if (bytes[i] == 0x0A) return i + 1;
    }
    return start;
  }
}
