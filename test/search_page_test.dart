import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glowhit_shopping/search_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GlowHit Search shows recent searches and voice search control', (tester) async {
    SharedPreferences.setMockInitialValues({
      'glowhit_recent_searches': ['watch for men', 'books'],
    });
    await tester.pumpWidget(MaterialApp(
      home: GlowHitSearchPage(onOpenProduct: (_) {}),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.text('watch for men'), findsOneWidget);
    expect(find.text('books'), findsOneWidget);
    expect(find.byTooltip('Voice Search'), findsOneWidget);
  });

  testWidgets('GlowHit Search lets users edit and clear recent searches', (tester) async {
    SharedPreferences.setMockInitialValues({
      'glowhit_recent_searches': ['watch', 'shirt'],
    });
    await tester.pumpWidget(MaterialApp(
      home: GlowHitSearchPage(onOpenProduct: (_) {}),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Edit'));
    await tester.pump();
    expect(find.byTooltip('Delete'), findsNWidgets(2));
    await tester.tap(find.text('Clear all'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('watch'), findsNothing);
    expect(find.text('shirt'), findsNothing);
  });
}
