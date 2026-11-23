import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'woo_store_api.dart';

const orderSuccessAnimationUrl =
    'https://pluginstore.shop/wp-content/themes/ark-material-commerce/assets/animations/order-success.json';

class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({super.key, required this.order, required this.cart, required this.api, required this.onContinue});
  final Map<String, dynamic> order;
  final Map<String, dynamic> cart;
  final WooStoreApi api;
  final VoidCallback onContinue;

  String amount() {
    final totals = order['totals'] is Map ? order['totals'] as Map : (cart['totals'] is Map ? cart['totals'] as Map : const {});
    final raw = int.tryParse('${totals['total_price'] ?? '0'}') ?? 0;
    final digits = (totals['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
    return '${totals['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
  }

  @override
  Widget build(BuildContext context) {
    final id = order['order_id'] ?? order['id'] ?? order['number'] ?? '—';
    final payment = order['payment_result'] is Map ? order['payment_result'] as Map : const {};
    final status = (order['status'] ?? payment['payment_status'] ?? 'Received').toString();
    final normalizedStatus = status.toLowerCase().replaceAll('_', '-');
    final awaitingVerification = normalizedStatus.contains('pending') || normalizedStatus.contains('on-hold');
    final message = awaitingVerification
        ? 'Your order has been received. UPI payment is awaiting store verification; your order is not marked as paid yet.'
        : 'Thank you! Your order has been sent to the store.';
    return Scaffold(
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
        SizedBox(height: 210, child: Lottie.network(
          orderSuccessAnimationUrl,
          fit: BoxFit.contain,
          repeat: true,
          errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 112)),
        )),
        const SizedBox(height: 8),
        Text(awaitingVerification ? 'Order received!' : 'Order placed successfully!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
        const SizedBox(height: 24),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          _detail('Order ID', '#$id'),
          const Divider(height: 24),
          _detail('Order amount', amount()),
          const Divider(height: 24),
          _detail('Payment status', status.toUpperCase()),
          const Divider(height: 24),
          _detail('Order status', (order['status'] ?? 'Received').toString().toUpperCase()),
        ]))),
        const SizedBox(height: 22),
        const Text('You may also like', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: api.getRecommendedProducts(limit: 6),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
            final products = snapshot.data!;
            return SizedBox(
              height: 238,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1, mainAxisExtent: 158, mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final images = product['images'] as List? ?? const [];
                  final image = images.isNotEmpty && images.first is Map
                      ? (images.first['thumbnail'] ?? images.first['src'] ?? '').toString() : '';
                  final prices = product['prices'] is Map ? product['prices'] as Map : const {};
                  final raw = int.tryParse('${prices['price'] ?? '0'}') ?? 0;
                  final digits = (prices['currency_minor_unit'] as num?)?.toInt() ?? 2;
                  final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
                  final price = '${prices['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        final link = Uri.tryParse((product['permalink'] ?? '').toString());
                        if (link != null) launchUrl(link, mode: LaunchMode.externalApplication);
                      },
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: image.isEmpty
                          ? const Center(child: Icon(Icons.shopping_bag_outlined, size: 42))
                          : Image.network(image, width: double.infinity, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined)))),
                        Padding(padding: const EdgeInsets.fromLTRB(8, 5, 8, 2), child: Text(
                          (product['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        )),
                        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text(
                          price, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF51408F)),
                        )),
                      ]),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        SizedBox(height: 54, child: FilledButton(onPressed: onContinue, child: const Text('CONTINUE SHOPPING'))),
      ])),
    );
  }

  Widget _detail(String label, String value) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: TextStyle(color: Colors.grey.shade700)),
    const SizedBox(width: 12),
    Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
  ]);
}
