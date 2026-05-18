import 'package:meta/meta.dart';

import '../config/config.dart';

/// Estimates Anthropic token counts from raw character length.
///
/// Anthropic's tokenizer is closed (BPE variant); local estimation always
/// carries a ±15% deviation (see `Config.tokenEstimation.estimatedDeviation`).
/// Byte and character counts are exact; the estimate is used for "tokens
/// saved" reporting where rough magnitude is enough.
@immutable
class TokenEstimator {
  final double charsPerToken;

  const TokenEstimator({this.charsPerToken = 3.8})
      : assert(charsPerToken > 0, 'charsPerToken must be positive');

  factory TokenEstimator.fromConfig(Config config) => TokenEstimator(
        charsPerToken: config.tokenEstimation.charsPerToken,
      );

  int estimate(String text) {
    if (text.isEmpty) return 0;
    return (text.length / charsPerToken).ceil();
  }
}
