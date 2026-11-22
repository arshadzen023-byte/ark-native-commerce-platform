import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

const orderSuccessAnimationUrl =
    'https://pluginstore.shop/wp-content/themes/ark-material-commerce/assets/animations/order-success.json';

class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({super.key, required this.order, required this.cart, required this.onContinue});
  final Map<String, dynamic> order;
  final Map<String, dynamic> cart;
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
      appBar: AppBar(title: const Text('Order confirmation'), automaticallyImplyLeading: false),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 24), children: [
        SizedBox(height: 210, child: Lottie.network(
          orderSuccessAnimationUrl,
          fit: BoxFit.contain,
          repeat: false,
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
