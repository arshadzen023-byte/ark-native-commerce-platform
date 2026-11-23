import 'package:flutter/material.dart';

/// Offline, native illustration inspired by the supplied QR-scan artwork.
class QrCodeScanIllustration extends StatelessWidget {
  const QrCodeScanIllustration({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 70,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: 1,
          top: 7,
          child: Container(
            width: 42,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF8E83E8),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x22827BE2), blurRadius: 5, offset: Offset(2, 3))],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2_rounded, color: Color(0xFFFFB56E), size: 31),
                SizedBox(height: 1),
                Icon(Icons.horizontal_rule_rounded, color: Color(0xFF5D4CA7), size: 18),
              ],
            ),
          ),
        ),
        Positioned(
          left: 2,
          top: 0,
          child: Container(
            width: 35,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFFECEBFF),
              border: Border.all(color: const Color(0xFF6253B4), width: 2),
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [BoxShadow(color: Color(0x22827BE2), blurRadius: 4, offset: Offset(1, 2))],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6657B6), size: 26),
          ),
        ),
        const Positioned(
          left: 0,
          bottom: 0,
          child: Icon(Icons.back_hand_rounded, color: Color(0xFFFFB17D), size: 31),
        ),
      ],
    ),
  );
}
