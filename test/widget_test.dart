import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/main.dart';

void main() {
  test('GlowHit is configured for the live WooCommerce store', () {
    expect(storeUrl, 'https://pluginstore.shop');
  });
}
