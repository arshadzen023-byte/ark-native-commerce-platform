import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/main.dart';

void main() {
  testWidgets('GlowHit app starts with the five shopping tabs', (tester) async {
    await tester.pumpWidget(const GlowHitApp());
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });
}
