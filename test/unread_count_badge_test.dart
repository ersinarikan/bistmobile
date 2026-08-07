import 'package:flutter/material.dart';
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

  testWidgets('UnreadCountBadge hides label when count is 0', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnreadCountBadge(
            count: 0,
            child: Icon(Icons.person_outline),
          ),
        ),
      ),
    );
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('UnreadCountBadge shows count and 99+', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnreadCountBadge(
            count: 28,
            child: Icon(Icons.notifications_outlined),
          ),
        ),
      ),
    );
    expect(find.text('28'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnreadCountBadge(
            count: 100,
            child: Icon(Icons.notifications_outlined),
          ),
        ),
      ),
    );
    expect(find.text('99+'), findsOneWidget);
  });
}
