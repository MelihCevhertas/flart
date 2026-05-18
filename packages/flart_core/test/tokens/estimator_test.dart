// ignore_for_file: depend_on_referenced_packages

import 'package:flart_core/flart_core.dart';
import 'package:test/test.dart';

void main() {
  group('TokenEstimator', () {
    test('empty string is zero tokens', () {
      expect(const TokenEstimator().estimate(''), 0);
    });

    test('default 3.8 chars/token, ceil division', () {
      const e = TokenEstimator();
      expect(e.estimate('a'), 1); // ceil(1/3.8)
      expect(e.estimate('abcd'), 2); // ceil(4/3.8) = ceil(1.05)
      expect(e.estimate('a' * 38), 10);
      expect(e.estimate('a' * 39), 11);
    });

    test('fromConfig pulls charsPerToken from Config.tokenEstimation', () {
      final c = Config.fromMap({
        'token_estimation': {
          'chars_per_token': 3.5,
          'estimated_deviation': 0.15,
        },
      });
      final e = TokenEstimator.fromConfig(c);
      expect(e.charsPerToken, 3.5);
      expect(e.estimate('a' * 35), 10);
    });

    test('asserts charsPerToken > 0', () {
      expect(
        () => TokenEstimator(charsPerToken: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
