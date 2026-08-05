import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/widgets/lotlot_accent_card.dart';

void main() {
  testWidgets('LotlotAccentCard renders child and accent strip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LotlotAccentCard(
            child: Text('body'),
          ),
        ),
      ),
    );
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(ColoredBox), findsWidgets);
  });

  testWidgets('LotlotAccentCard onTap fires', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LotlotAccentCard(
            onTap: () => taps++,
            child: const Text('tappable'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tappable'));
    expect(taps, 1);
  });

  testWidgets('LotlotAccentCard applies margin', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LotlotAccentCard(
            margin: EdgeInsets.all(8),
            child: Text('padded'),
          ),
        ),
      ),
    );
    expect(find.byType(Padding), findsWidgets);
    expect(find.text('padded'), findsOneWidget);
  });
}
