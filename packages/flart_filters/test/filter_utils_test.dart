// ignore_for_file: depend_on_referenced_packages

import 'package:flart_filters/flart_filters.dart';
import 'package:test/test.dart';

void main() {
  group('FilterUtils.truncateMessage', () {
    test('messages within the cap pass through', () {
      expect(FilterUtils.truncateMessage('short', 100), 'short');
      expect(FilterUtils.truncateMessage('', 100), '');
    });

    test('messages over the cap get a hint suffix', () {
      final msg = 'x' * 500;
      final result = FilterUtils.truncateMessage(msg, 100);
      expect(result.length, lessThan(msg.length));
      expect(result, startsWith('x' * 100));
      expect(result, contains('… (+400 chars)'));
    });

    test('maxLen <= 0 disables truncation', () {
      final msg = 'x' * 500;
      expect(FilterUtils.truncateMessage(msg, 0), msg);
      expect(FilterUtils.truncateMessage(msg, -1), msg);
    });

    test('exact-length boundary is not truncated', () {
      final msg = 'x' * 100;
      expect(FilterUtils.truncateMessage(msg, 100), msg);
    });
  });
}
