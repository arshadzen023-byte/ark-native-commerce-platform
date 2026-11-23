import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/main.dart';

void main() {
  testWidgets('GlowHit login landing page displays sign-in fields', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginLandingPage(onLogin: (_) {}),
      ),
    );

    expect(find.text('Welcome to GlowHit'), findsOneWidget);
    expect(find.text('Sign in to continue shopping'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
