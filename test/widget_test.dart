import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/glowhit_designer_page.dart';
import 'package:glowhit_shopping/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GlowHit remains configured for the live WooCommerce store', () {
    expect(storeUrl, 'https://pluginstore.shop');
  });

  testWidgets('Designer shows page selector, components and add menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: GlowHitDesignerPage(token: 'test-token')));
    await tester.pumpAndSettle();
    expect(find.text('ARK Designer'), findsOneWidget);
    expect(find.text('Edit page'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Main promotional banner'), findsOneWidget);
    expect(find.text('Add component'), findsOneWidget);
    await tester.tap(find.text('Add component'));
    await tester.pumpAndSettle();
    expect(find.text('Add a component'), findsOneWidget);
    expect(find.text('Banner layout'), findsOneWidget);
  });

  testWidgets('Designer can edit component properties and save draft locally', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: GlowHitDesignerPage(token: 'test-token')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main promotional banner'));
    await tester.pumpAndSettle();
    expect(find.text('Component Properties'), findsOneWidget);
    expect(find.text('LIVE COMPONENT PREVIEW'), findsOneWidget);
    expect(find.text('Banner style'), findsOneWidget);
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('ARK Designer'), findsOneWidget);
  });
}
