import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/main.dart';

void main() {
  testWidgets('GlowHit shopping app shows the home screen', (tester) async {
    await tester.pumpWidget(const GlowHitApp());
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
