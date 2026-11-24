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
    await tester.pumpWidget(const MaterialApp(
      home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ARK Designer'), findsOneWidget);
    expect(find.text('Edit page'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Main promotional banner').first, findsOneWidget);
    expect(find.text('Add component'), findsOneWidget);

    await tester.tap(find.text('Add component'));
    await tester.pumpAndSettle();
    expect(find.text('Banner'), findsWidgets);
    expect(find.text('Category'), findsWidgets);
    expect(find.text('Product'), findsWidgets);
    await tester.tap(find.text('Banner').last);
    await tester.pumpAndSettle();
    expect(find.text('Banner Grid'), findsOneWidget);
    expect(find.text('Banner Slider'), findsNWidgets(2));
  });

  testWidgets('Designer property editor exposes live preview, tabs and child tools', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
      home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Main promotional banner').first);
    await tester.pumpAndSettle();

    // Assert the current reference-style editor, rather than the retired
    // pre-redesign "Component layout / Design / JSON" labels.
    expect(find.text('LIVE COMPONENT PREVIEW'), findsOneWidget);
    expect(find.text('Padding'), findsOneWidget);
    expect(find.text('Margin'), findsOneWidget);
    expect(find.text('Dimension'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Children'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Layout type'), findsOneWidget);
    expect(find.text('Title'), findsWidgets);
    expect(find.text('Description'), findsOneWidget);

    await tester.tap(find.text('Style'));
    await tester.pumpAndSettle();
    expect(find.text('Background Color'), findsOneWidget);
    expect(find.text('Title Color'), findsOneWidget);
    expect(find.textContaining('Font Family:'), findsOneWidget);

    await tester.tap(find.text('Children'));
    await tester.pumpAndSettle();
    expect(find.text('Add image / video'), findsOneWidget);
    expect(find.text('Add text'), findsOneWidget);
    expect(find.text('Add link'), findsOneWidget);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('ARK Designer'), findsOneWidget);
  });
}
