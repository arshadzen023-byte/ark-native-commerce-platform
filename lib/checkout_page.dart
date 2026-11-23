import 'package:flutter/material.dart';
import 'delivery_address_page.dart';
import 'order_confirmation_page.dart';
import 'order_summary_page.dart';
import 'payment_page.dart';
import 'woo_store_api.dart';

class WooCheckoutPage extends StatefulWidget {
  const WooCheckoutPage({super.key, required this.api, this.customerToken});
  final WooStoreApi api;
  final String? customerToken;
  @override
  State<WooCheckoutPage> createState() => _WooCheckoutPageState();
}

class _WooCheckoutPageState extends State<WooCheckoutPage> {
  Map<String, dynamic> cart = {};
  Map<String, dynamic> address = {};
  bool loading = true;
  int step = 0;
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
      builder: (_) => DeliveryAddressPage(api: widget.api, initialAddress: address, customerToken: widget.customerToken),
    ));
    if (result == null || !mounted) return;
    address = Map<String, dynamic>.from(result['address'] as Map);
    if (result['cart'] is Map) cart = Map<String, dynamic>.from(result['cart'] as Map);
    await openPayment();
  }

  Future<void> _selectShippingRate(Map<String, dynamic> rate) async {
    final rateId = (rate['rate_id'] ?? rate['id'] ?? '').toString();
    final packageId = (rate['package_id'] as num?)?.toInt() ?? 0;
    if (rateId.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final updated = await widget.api.selectShippingRate(packageId, rateId);
      if (mounted) setState(() { cart = updated; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
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
        api: widget.api,
        onContinue: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null && cart.isEmpty) {
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
    final steps = ['Summary', 'Address', 'Confirm details'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: step > 0 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => step--)) : null,
        actions: [IconButton(onPressed: loading ? null : loadCart, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: Column(children: [
          Row(children: List.generate(3, (i) => Expanded(child: Container(margin: EdgeInsets.only(right: i == 2 ? 0 : 6), height: 5, decoration: BoxDecoration(color: step >= i ? const Color(0xFF51408F) : Colors.grey.shade300, borderRadius: BorderRadius.circular(8)))))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(3, (i) => Text(steps[i], style: TextStyle(fontSize: 12, color: step >= i ? const Color(0xFF51408F) : Colors.grey, fontWeight: step == i ? FontWeight.bold : FontWeight.normal)))),
        ])),
        Expanded(child: step == 0
          ? OrderSummaryPage(cart: cart, onContinue: () => setState(() => step = 1), onQuantityChanged: (key, quantity) async {
              if (key.isEmpty) return;
              setState(() => loading = true);
              try { final updated = quantity <= 0 ? await widget.api.removeItem(key) : await widget.api.updateItem(key, quantity); if (mounted) setState(() { cart = updated; loading = false; error = null; }); }
              catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; }); }
            }, onRemove: (key) async {
              if (key.isEmpty) return;
              setState(() => loading = true);
              try { final updated = await widget.api.removeItem(key); if (mounted) setState(() { cart = updated; loading = false; error = null; }); }
              catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; }); }
            })
          : step == 1
            ? DeliveryAddressPage(api: widget.api, initialAddress: address, customerToken: widget.customerToken, embedded: true, onAddressSaved: (value, updated) {
                setState(() { address = value; cart = updated; step = 2; error = null; });
              })
            : _paymentReview()),
      ]),
    );
  }

  Widget _paymentReview() {
    final totals = cart['totals'] is Map ? cart['totals'] as Map : const {};
    final lines = (cart['items'] as List? ?? []).whereType<Map>().toList();
    final currency = (totals['currency_symbol'] ?? '₹').toString();
    final raw = int.tryParse('${totals['total_price'] ?? '0'}') ?? 0;
    final digits = (totals['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final amount = '$currency${(raw / (digits == 0 ? 1 : digits == 1 ? 10 : 100)).toStringAsFixed(digits)}';
    final packages = (cart['shipping_rates'] as List? ?? cart['packages'] as List? ?? const []);
    final shippingRates = <Map<String, dynamic>>[];
    for (final package in packages.whereType<Map>()) {
      final packageId = (package['package_id'] as num?)?.toInt() ?? 0;
      for (final rate in (package['shipping_rates'] as List? ?? const []).whereType<Map>()) {
        shippingRates.add({...Map<String, dynamic>.from(rate), 'package_id': packageId});
      }
    }
    String shippingPrice(Map rate) {
      final value = int.tryParse('${rate['price'] ?? rate['cost'] ?? '0'}') ?? 0;
      final unit = (rate['currency_minor_unit'] as num?)?.toInt() ?? digits;
      final divisor = unit == 0 ? 1 : (unit == 1 ? 10 : 100);
      return '${rate['currency_symbol'] ?? currency}${(value / divisor).toStringAsFixed(unit)}';
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Confirm details', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Review your delivery address, items and total before payment.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5E1EF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFF0EDFA), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF51408F)),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Delivering to', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
              TextButton(onPressed: () => setState(() => step = 1), child: const Text('CHANGE')),
            ]),
            const SizedBox(height: 8),
            Text(
              [address['first_name'], address['last_name']].where((v) => v != null && v.toString().trim().isNotEmpty).join(' '),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 5),
            Text(
              [address['address_1'], address['address_2'], address['city'], address['state'], address['postcode'], address['country']]
                  .where((v) => v != null && v.toString().trim().isNotEmpty).join(', '),
              style: const TextStyle(height: 1.4),
            ),
            if ((address['phone'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 7),
              Row(children: [const Icon(Icons.phone_outlined, size: 17), const SizedBox(width: 7), Text(address['phone'].toString())]),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5E1EF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Order items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 10),
            for (final item in lines) ...[
              Builder(builder: (context) {
                final images = item['images'] as List? ?? const [];
                final image = images.isNotEmpty && images.first is Map
                    ? (images.first['thumbnail'] ?? images.first['src'] ?? '').toString()
                    : '';
                final itemTotals = item['totals'] is Map ? item['totals'] as Map : const {};
                final lineTotal = int.tryParse('${itemTotals['line_total'] ?? '0'}') ?? 0;
                final unit = (itemTotals['currency_minor_unit'] as num?)?.toInt() ?? digits;
                final divisor = unit == 0 ? 1 : (unit == 1 ? 10 : 100);
                final linePrice = '${itemTotals['currency_symbol'] ?? currency}${(lineTotal / divisor).toStringAsFixed(unit)}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 76, height: 76, color: const Color(0xFFF7F6FA),
                        child: image.isEmpty
                            ? const Icon(Icons.shopping_bag_outlined, color: Color(0xFF51408F))
                            : Image.network(image, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((item['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text('Qty: ${item['quantity'] ?? 1}', style: const TextStyle(color: Colors.black54)),
                    ])),
                    const SizedBox(width: 8),
                    Text(linePrice, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                );
              }),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Choose shipping method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        if (shippingRates.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('No shipping rates returned for this address. Check the WooCommerce shipping zone.', style: TextStyle(color: Colors.orange.shade800))),
        ...shippingRates.map((rate) {
          final id = (rate['rate_id'] ?? rate['id'] ?? '').toString();
          return RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: id,
            groupValue: shippingRates.where((r) => r['selected'] == true).map((r) => (r['rate_id'] ?? r['id'] ?? '').toString()).firstOrNull,
            onChanged: loading ? null : (_) => _selectShippingRate(rate),
            title: Text((rate['name'] ?? rate['method_title'] ?? id).toString()),
            subtitle: Text(shippingPrice(rate)),
            activeColor: const Color(0xFF51408F),
          );
        }),
      ]))),
      const SizedBox(height: 10),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total payable', style: TextStyle(fontWeight: FontWeight.bold)), Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF51408F)))]))),
      const SizedBox(height: 12),
      SizedBox(height: 54, child: FilledButton(onPressed: loading || address['address_1'] == null || address['address_1'].toString().trim().isEmpty || (shippingRates.isNotEmpty && !shippingRates.any((r) => r['selected'] == true)) ? null : openPayment, child: const Text('CONTINUE TO PAYMENTS'))),
    ]);
  }
}
