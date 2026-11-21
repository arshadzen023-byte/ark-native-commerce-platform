import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'woo_store_api.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.api, required this.address, required this.cart});
  final WooStoreApi api;
  final Map<String, dynamic> address;
  final Map<String, dynamic> cart;
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<Map<String, dynamic>> methods = [];
  String? selected;
  bool loading = true, paying = false;
  String? error;

  @override
  void initState() { super.initState(); loadMethods(); }

  Future<void> loadMethods() async {
    try {
      final checkout = await widget.api.getCheckout();
      final list = (checkout['payment_methods'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (mounted) setState(() { methods = list; selected = list.isEmpty ? null : list.first['id']?.toString(); loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }

  String money(Map? data) {
    if (data == null) return '';
    final raw = int.tryParse('${data['total_price'] ?? '0'}') ?? 0;
    final digits = (data['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
    return '${data['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
  }

  Future<void> placeOrder() async {
    if (selected == null) {
      setState(() => error = 'No active payment method was returned by WooCommerce. Enable COD or an online gateway in WooCommerce → Settings → Payments.');
      return;
    }
    setState(() { paying = true; error = null; });
    try {
      final result = await widget.api.placeOrder(billing: widget.address, shipping: widget.address, paymentMethod: selected!);
      final payment = result['payment_result'];
      final redirect = payment is Map ? (payment['redirect_url'] ?? '').toString() : '';
      if (redirect.isNotEmpty && redirect != 'null') {
        final uri = Uri.tryParse(redirect);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = widget.cart['totals'] is Map ? widget.cart['totals'] as Map : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Choose payment method', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Payments are processed by the payment methods enabled in your WooCommerce store.'),
        const SizedBox(height: 16),
        if (methods.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error ?? 'WooCommerce returned no active payment methods. Enable Cash on Delivery or an online gateway in WooCommerce settings.', style: const TextStyle(color: Colors.deepOrange))))
        else
          ...methods.map((method) {
            final id = (method['id'] ?? '').toString();
            return Card(child: RadioListTile<String>(
              value: id, groupValue: selected, onChanged: paying ? null : (value) => setState(() => selected = value),
              title: Text((method['title'] ?? id).toString()),
              subtitle: method['description'] == null ? null : Text(method['description'].toString()),
              activeColor: const Color(0xFF51408F),
            ));
          }),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Payable amount', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(money(totals), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF51408F))),
        ]))),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 22),
        SizedBox(height: 54, child: FilledButton(
          onPressed: paying || methods.isEmpty ? null : placeOrder,
          child: paying ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('PLACE ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}
