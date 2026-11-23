import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/woo_store_api.dart';

void main() {
  group('WooCommerce order confirmation guard', () {
    test('accepts a real order ID from Store API', () {
      expect(WooStoreApi.confirmedOrderId({'order_id': 455, 'status': 'on-hold'}), 455);
      expect(WooStoreApi.confirmedOrderId({'id': '456', 'status': 'processing'}), 456);
    });

    test('rejects a success-shaped response without a real order ID', () {
      expect(
        () => WooStoreApi.confirmedOrderId({'status': 'on-hold', 'message': 'Order received'}),
        throwsException,
      );
      expect(
        () => WooStoreApi.confirmedOrderId({'order_id': 0}),
        throwsException,
      );
    });

    test('rejects failed or cancelled order statuses', () {
      expect(() => WooStoreApi.confirmedOrderId({'order_id': 457, 'status': 'failed'}), throwsException);
      expect(() => WooStoreApi.confirmedOrderId({'order_id': 458, 'status': 'cancelled'}), throwsException);
    });
  });
}
