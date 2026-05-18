/// Cross-filter helpers. Centralizes shared transformations so each filter
/// doesn't re-invent the same logic.
class FilterUtils {
  /// Truncates [message] to at most [maxLen] characters. When truncation
  /// happens an `… (+N chars)` suffix is appended so the agent knows the
  /// message was clipped.
  ///
  /// [maxLen] <= 0 means "no truncation" — the message passes through.
  /// This keeps callers from special-casing the disabled state.
  static String truncateMessage(String message, int maxLen) {
    if (maxLen <= 0 || message.length <= maxLen) return message;
    final remaining = message.length - maxLen;
    return '${message.substring(0, maxLen)}… (+$remaining chars)';
  }
}
