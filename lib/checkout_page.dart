import 'package:flutter/material.dart';
import 'delivery_address_page.dart';
import 'order_confirmation_page.dart';
import 'order_summary_page.dart';
import 'payment_page.dart';
import 'woo_store_api.dart';

class WooCheckoutPage extends StatefulWidget {
  const WooCheckoutPage({super.key, required this.api});
  final WooStoreApi api;
  @override
  State<WooCheckoutPage> createState() => _WooCheckoutPageState();
}

class _WooCheckoutPageState extends State<WooCheckoutPage> {
  Map<String, dynamic> cart = {};
  Map<String, dynamic> address = {};
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); loadCart(); }

  Future<void> loadCart() async {
    try {
      final value = await widget.api.getCart();
      final billing = value['billing_address'] is Map
          ? Map<String, dynamic>.from(value['billing_address'])
          : <String, dynamic>{};
      if (mounted) setState(() { cart = value; address = billing; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }

  Future<void> openAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(
      builder: (_) => DeliveryAddressPage(api: widget.api, initialAddress: address),
    ));
    if (result == null || !mounted) return;
    address = Map<String, dynamic>.from(result['address'] as Map);
    if (result['cart'] is Map) cart = Map<String, dynamic>.from(result['cart'] as Map);
    await openPayment();
  }

  Future<void> openPayment() async {
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(
      builder: (_) => PaymentPage(api: widget.api, address: address, cart: cart),
    ));
    if (result == null || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => OrderConfirmationPage(
        order: result,
        cart: cart,
        onContinue: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.deepOrange),
          const SizedBox(height: 12),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: () { setState(() { loading = true; error = null; }); loadCart(); }, child: const Text('RETRY')),
        ]))),
      );
    }
    return OrderSummaryPage(cart: cart, onContinue: openAddress);
  }
}
