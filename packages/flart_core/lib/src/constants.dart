/// Hard-coded thresholds for the PostToolUse / Bash output filter (v0.3.0).
///
/// Kept here so flart_core owns the data-model defaults. v0.4.0 may lift
/// these into YAML config; until then the values are baked into the binary.
class BashFilterThresholds {
  /// Outputs with fewer or equal lines than this are emitted unchanged —
  /// the agent sees them as if no hook ran. Hot path; keep small.
  final int passthroughLines;

  /// Outputs above this many lines switch from "head 20 + tail 5" to the
  /// large-output strategy (head 15 + tail 5 + error-grep summary).
  final int largeLines;

  /// First N lines preserved in the medium-output strategy (between
  /// [passthroughLines] and [largeLines]).
  final int mediumHeadLines;

  /// Trailing N lines preserved in the medium-output strategy.
  final int mediumTailLines;

  /// First N lines preserved in the large-output strategy (> [largeLines]).
  final int largeHeadLines;

  /// Trailing N lines preserved in the large-output strategy.
  final int largeTailLines;

  /// Maximum error-flavoured lines pulled from the body of a large output.
  final int largeErrorLines;

  /// On non-zero exit code, keep stderr capped at this many bytes. Plan v1.15:
  /// errors are the highest-signal portion of a failure, so the cap is
  /// generous (2 KB) — we'd rather pay tokens than drop the message.
  final int errorStderrCapBytes;

  /// On non-zero exit code, keep the last N lines of stdout for trace context.
  /// Plan v1.15: 20 (not 10 — trace context often needs more breathing room).
  final int errorStdoutTailLines;

  const BashFilterThresholds({
    this.passthroughLines = 30,
    this.largeLines = 200,
    this.mediumHeadLines = 20,
    this.mediumTailLines = 5,
    this.largeHeadLines = 15,
    this.largeTailLines = 5,
    this.largeErrorLines = 10,
    this.errorStderrCapBytes = 2048,
    this.errorStdoutTailLines = 20,
  });

  static const BashFilterThresholds defaults = BashFilterThresholds();
}
