import 'package:flutter_test/flutter_test.dart';
import 'package:lotlotnet_mobile/main.dart';

void main() {
  testWidgets('Splash shows LOTLOT brand', (tester) async {
    await tester.pumpWidget(const LotlotApp(firebaseReady: false));
    // Splash starts async bootstrap — allow frames.
    await tester.pump();
    expect(find.textContaining('LOTLOT'), findsWidgets);
  });
}
