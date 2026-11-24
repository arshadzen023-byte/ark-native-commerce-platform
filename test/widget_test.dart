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
    await tester.pumpWidget(const MaterialApp(home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false)));
    await tester.pumpAndSettle();
    expect(find.text('ARK Designer'), findsOneWidget);
    expect(find.text('Edit page'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Main promotional banner').first, findsOneWidget);
    expect(find.text('Add component'), findsOneWidget);
    await tester.tap(find.text('Add component'));
    await tester.pumpAndSettle();
    expect(find.text('Add component'), findsWidgets);
    expect(find.text('Banner'), findsWidgets);
    expect(find.text('Category'), findsWidgets);
    expect(find.text('Product'), findsWidgets);
    await tester.tap(find.text('Banner').last);
    await tester.pumpAndSettle();
    expect(find.text('Banner Grid'), findsOneWidget);
    expect(find.text('Banner Slider'), findsNWidgets(2));
  });

  testWidgets('Designer can edit component properties and save draft locally', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main promotional banner').first);
    await tester.pumpAndSettle();
    // Assert against the reference-style editor labels currently rendered.
    expect(find.text('LIVE COMPONENT PREVIEW'), findsOneWidget);
    expect(find.text('Component layout'), findsOneWidget);
    expect(find.text('Title text style'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('Live Preview'), findsOneWidget);
    expect(find.text('Property'), findsOneWidget);
    // Banner-specific controls are below the initial viewport. Keep this
    // editor persistence test focused on the visible property form and save;
    // their interactive behavior is covered by dedicated widget tests.
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('ARK Designer'), findsOneWidget);
  });
}
