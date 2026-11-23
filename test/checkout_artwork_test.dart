import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/checkout_artwork.dart';

void main() {
  test('checkout illustrations are bundled as valid PNG byte streams', () {
    const pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    expect(CheckoutArtwork.fastDelivery.take(8).toList(), pngSignature);
    expect(CheckoutArtwork.rupee.take(8).toList(), pngSignature);
    expect(CheckoutArtwork.smartphone.take(8).toList(), pngSignature);
    expect(CheckoutArtwork.qrScan.take(8).toList(), pngSignature);
    expect(CheckoutArtwork.fastDelivery.length, greaterThan(500));
    expect(CheckoutArtwork.rupee.length, greaterThan(500));
    expect(CheckoutArtwork.smartphone.length, greaterThan(500));
    expect(CheckoutArtwork.qrScan.length, greaterThan(500));
  });
}
