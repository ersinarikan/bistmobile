import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/widgets/unread_count_badge.dart';

void main() {
  test('formatUnreadBadgeCount', () {
    expect(formatUnreadBadgeCount(0), '');
    expect(formatUnreadBadgeCount(-1), '');
    expect(formatUnreadBadgeCount(1), '1');
    expect(formatUnreadBadgeCount(28), '28');
    expect(formatUnreadBadgeCount(99), '99');
    expect(formatUnreadBadgeCount(100), '99+');
  });
}
