import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/qr_code_scan_illustration.dart';

void main() {
  testWidgets('UPI payment QR scan illustration renders offline', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: QrCodeScanIllustration())));
    expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    expect(find.byIcon(Icons.back_hand_rounded), findsOneWidget);
  });
}
