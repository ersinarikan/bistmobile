import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/core/widgets/oauth_brand_icons.dart';

void main() {
  testWidgets('GoogleLogoMark paints without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: GoogleLogoMark(size: 24)),
        ),
      ),
    );
    expect(find.byType(GoogleLogoMark), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('AppleLogoMark paints with custom color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppleLogoMark(size: 24, color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
    expect(find.byType(AppleLogoMark), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppleLogoMark(size: 20, color: Color(0xFF000000)),
          ),
        ),
      ),
    );
    expect(find.byType(AppleLogoMark), findsOneWidget);
  });
}
