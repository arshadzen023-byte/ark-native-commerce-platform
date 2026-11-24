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

  testWidgets('Designer gallery shows component previews without title or edit controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
      home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ARK Designer'), findsOneWidget);
    expect(find.text('Edit page'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Tap to edit properties'), findsNothing);
    expect(find.text('Banner Slider'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add component'), findsOneWidget);
    expect(find.text('Banner'), findsWidgets);
    expect(find.text('Category'), findsWidgets);
    expect(find.text('Product'), findsWidgets);
    await tester.tap(find.text('Banner').last);
    await tester.pumpAndSettle();
    expect(find.text('Banner Grid'), findsOneWidget);
    expect(find.text('Banner Slider'), findsNWidgets(2));
  });

  testWidgets('Designer editor exposes seven live property tabs and child tools', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
      home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Banner Slider').first);
    await tester.pumpAndSettle();

    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Color'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Title'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Padding'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Margin'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Dimension'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Settings'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Style'), hasLength(1));

    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Title Text Style'), findsOneWidget);

    final titleStyleButton = find.text('Title Text Style');
    await tester.ensureVisible(titleStyleButton);
    await tester.pumpAndSettle();
    await tester.tap(titleStyleButton);
    await tester.pumpAndSettle();
    expect(find.text('Text Style'), findsOneWidget);
    expect(find.text('Sample Text'), findsOneWidget);
    expect(find.text('Search Font'), findsNothing);
    // The typography controls are intentionally below the live preview and
    // swatches in a scrollable property page; scroll them into the lazy list.
    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(find.text('Font Family'), findsOneWidget);
    await tester.tap(find.text('Font Family'));
    await tester.pumpAndSettle();
    expect(find.text('Search Font'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Style'));
    await tester.pumpAndSettle();
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Autoplay'), findsOneWidget);
    expect(find.text('View Fraction'), findsOneWidget);
    expect(find.text('Fade'), findsOneWidget);
    expect(find.text('Dot'), findsOneWidget);
    expect(find.text('Arrow'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Component Status'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Add image / video'), findsOneWidget);
    expect(find.text('Add text'), findsOneWidget);
    expect(find.text('Add link'), findsOneWidget);

    await tester.tap(find.byTooltip('View live component JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Live Component JSON'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('ARK Designer'), findsOneWidget);
  });
}
