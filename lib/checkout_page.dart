import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'woo_store_api.dart';

class WooCheckoutPage extends StatefulWidget {
  const WooCheckoutPage({super.key, required this.api});
  final WooStoreApi api;
  @override State<WooCheckoutPage> createState() => _WooCheckoutPageState();
}

class _WooCheckoutPageState extends State<WooCheckoutPage> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController(), _last = TextEditingController();
  final _email = TextEditingController(), _phone = TextEditingController();
  final _address = TextEditingController(), _city = TextEditingController();
  final _state = TextEditingController(), _postcode = TextEditingController();
  final _country = TextEditingController(text: 'IN');
  final _note = TextEditingController();
  Map<String, dynamic> cart = {};
  List<Map<String, dynamic>> paymentMethods = [];
  List<Map<String, dynamic>> shippingRates = [];
  String? selectedPayment, selectedRate;
  bool loading = true, working = false;
  String? error;
  Map<String, dynamic>? orderResult;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    for (final c in [_first,_last,_email,_phone,_address,_city,_state,_postcode,_country,_note]) { c.dispose(); }
    super.dispose();
  }
  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final c = await widget.api.getCart();
      final checkout = await widget.api.getCheckout();
      final methods = (c['payment_methods'] as List? ?? checkout['payment_methods'] as List? ?? []).map((e) => e is Map ? Map<String,dynamic>.from(e) : {'id': e.toString(), 'title': e.toString()}).toList();
      final packages = (c['shipping_rates'] as List? ?? c['packages'] as List? ?? []);
      final rates = <Map<String,dynamic>>[];
      for (final pkg in packages.whereType<Map>()) {
        final packageId = (pkg['package_id'] as num?)?.toInt() ?? 0;
        final list = (pkg['shipping_rates'] as List? ?? []);
        for (final item in list.whereType<Map>()) {
          rates.add({...Map<String,dynamic>.from(item), 'package_id': packageId});
        }
      }
      final customer = c['billing_address'] is Map ? Map<String,dynamic>.from(c['billing_address']) : <String,dynamic>{};
      if (_first.text.isEmpty) _first.text = (customer['first_name'] ?? '').toString();
      if (_last.text.isEmpty) _last.text = (customer['last_name'] ?? '').toString();
      if (_email.text.isEmpty) _email.text = (customer['email'] ?? '').toString();
      if (_phone.text.isEmpty) _phone.text = (customer['phone'] ?? '').toString();
      if (_address.text.isEmpty) _address.text = (customer['address_1'] ?? '').toString();
      if (_city.text.isEmpty) _city.text = (customer['city'] ?? '').toString();
      if (_state.text.isEmpty) _state.text = (customer['state'] ?? '').toString();
      if (_postcode.text.isEmpty) _postcode.text = (customer['postcode'] ?? '').toString();
      if (mounted) setState(() { cart = c; paymentMethods = methods; shippingRates = rates; selectedPayment = methods.isEmpty ? null : methods.first['id']?.toString(); final selectedRates = rates.where((r) => r['selected'] == true).map((r) => (r['rate_id'] ?? '').toString()).toList(); selectedRate = selectedRates.isEmpty ? null : selectedRates.first; loading = false; });
    } catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; }); }
  }
  Map<String,dynamic> _addressData() => {
    'first_name': _first.text.trim(), 'last_name': _last.text.trim(),
    'email': _email.text.trim(), 'phone': _phone.text.trim(),
    'address_1': _address.text.trim(), 'city': _city.text.trim(),
    'state': _state.text.trim(), 'postcode': _postcode.text.trim(),
    'country': _country.text.trim().toUpperCase(),
  };
  String _total() {
    final totals = cart['totals'];
    if (totals is! Map) return '0';
    return (totals['total_price'] ?? '0').toString();
  }
  String _money(dynamic value) {
    if (value is! Map) return '';
    final raw = int.tryParse((value['total_price'] ?? '0').toString()) ?? 0;
    final digits = (value['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
    return '${value['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
  }
  Future<void> _calculateShipping() async {
    if (!_form.currentState!.validate()) return;
    setState(() { working = true; error = null; });
    try {
      final address = _addressData();
      final updated = await widget.api.updateCustomer(billing: address, shipping: address);
      final packages = (updated['shipping_rates'] as List? ?? updated['packages'] as List? ?? []);
      final rates = <Map<String,dynamic>>[];
      for (final pkg in packages.whereType<Map>()) {
        final packageId = (pkg['package_id'] as num?)?.toInt() ?? 0;
        for (final item in (pkg['shipping_rates'] as List? ?? []).whereType<Map>()) {
          rates.add({...Map<String,dynamic>.from(item), 'package_id': packageId});
        }
      }
      setState(() { cart = updated; shippingRates = rates; selectedRate = rates.where((r) => r['selected'] == true).map((r) => (r['rate_id'] ?? '').toString()).firstOrNull; });
      if (rates.isEmpty) setState(() => error = 'No shipping rates returned for this address. Check WooCommerce shipping zones and methods for this PIN code.');
    } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => working = false); }
  }
  Future<void> _chooseRate(Map<String,dynamic> rate) async {
    setState(() { working = true; error = null; });
    try {
      final id = (rate['rate_id'] ?? rate['id'] ?? '').toString();
      final packageId = (rate['package_id'] as num?)?.toInt() ?? 0;
      final updated = await widget.api.selectShippingRate(packageId, id);
      setState(() { cart = updated; selectedRate = id; });
    } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => working = false); }
  }
  Future<void> _placeOrder() async {
    if (!_form.currentState!.validate()) return;
    if (selectedPayment == null) { setState(() => error = 'WooCommerce has not returned any active payment methods. Enable COD or an online gateway in WooCommerce settings.'); return; }
    setState(() { working = true; error = null; });
    try {
      final address = _addressData();
      await widget.api.updateCustomer(billing: address, shipping: address);
      final result = await widget.api.placeOrder(
        billing: address, shipping: address, paymentMethod: selectedPayment!,
        expectedTotal: _total(), customerNote: _note.text.trim(),
      );
      if (mounted) setState(() => orderResult = result);
      final payment = result['payment_result'];
      final redirect = payment is Map ? (payment['redirect_url'] ?? '').toString() : '';
      if (redirect.isNotEmpty && redirect != 'null') {
        final uri = Uri.tryParse(redirect);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => working = false); }
  }
  Widget _field(TextEditingController c, String label, {TextInputType type = TextInputType.text, bool required = true}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), validator: (v) => required && (v == null || v.trim().isEmpty) ? 'Required' : null));

  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (orderResult != null) {
      final order = orderResult!;
      final id = order['order_id'] ?? order['id'] ?? '—';
      final status = order['status'] ?? (order['payment_result'] is Map ? order['payment_result']['payment_status'] : null) ?? 'Processing';
      final total = order['totals'] is Map ? _money(order['totals']) : _money(cart['totals']);
      return Scaffold(appBar: AppBar(title: const Text('Order confirmation')), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 16), const Text('Order submitted', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18), Text('Order ID: $id'), Text('Amount: $total'), Text('Status: $status'),
        const SizedBox(height: 20), const Text('The final payment status is confirmed by WooCommerce.', textAlign: TextAlign.center),
        const SizedBox(height: 20), FilledButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Continue shopping')),
      ]))));
    }
    final items = cart['items'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (error != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.withOpacity(.08), borderRadius: BorderRadius.circular(10)), child: Text(error!, style: const TextStyle(color: Colors.red))),
        Text('Delivery address', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Form(key: _form, child: Column(children: [
          Row(children: [Expanded(child: _field(_first, 'First name')), const SizedBox(width: 10), Expanded(child: _field(_last, 'Last name'))]),
          _field(_email, 'Email', type: TextInputType.emailAddress),
          _field(_phone, 'Phone', type: TextInputType.phone),
          _field(_address, 'Address'),
          Row(children: [Expanded(child: _field(_city, 'City')), const SizedBox(width: 10), Expanded(child: _field(_state, 'State'))]),
          Row(children: [Expanded(child: _field(_postcode, 'PIN code', type: TextInputType.number)), const SizedBox(width: 10), Expanded(child: _field(_country, 'Country code'))]),
          OutlinedButton.icon(onPressed: working ? null : _calculateShipping, icon: const Icon(Icons.local_shipping_outlined), label: const Text('CALCULATE SHIPPING')),
        ]),
        const Divider(height: 32),
        Text('Shipping', style: Theme.of(context).textTheme.titleLarge),
        if (shippingRates.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Enter your address and calculate available shipping rates.'))
        else ...shippingRates.map((rate) {
          final id = (rate['rate_id'] ?? rate['id'] ?? '').toString();
          final label = (rate['name'] ?? rate['method_title'] ?? id).toString();
          final cost = rate['price'] ?? rate['cost'] ?? '';
          return RadioListTile<String>(value: id, groupValue: selectedRate, onChanged: working ? null : (_) => _chooseRate(rate), title: Text(label), subtitle: Text(cost.toString()), dense: true);
        }),
        const Divider(height: 32),
        Text('Payment', style: Theme.of(context).textTheme.titleLarge),
        if (paymentMethods.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('WooCommerce did not return active payment methods. Enable Cash on Delivery or an online gateway in WooCommerce → Settings → Payments.'))
        else ...paymentMethods.map((method) {
          final id = method['id'].toString();
          return RadioListTile<String>(value: id, groupValue: selectedPayment, onChanged: (v) => setState(() => selectedPayment = v), title: Text((method['title'] ?? id).toString()), subtitle: method['description'] == null ? null : Text(method['description'].toString()), dense: true);
        }),
        TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Order note (optional)')),
        const Divider(height: 32),
        Text('Order summary', style: Theme.of(context).textTheme.titleLarge),
        ...items.whereType<Map>().map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text((item['name'] ?? 'Product').toString()), subtitle: Text('Qty: ${item['quantity'] ?? 1}'), trailing: Text(_money(item['totals'] is Map ? item['totals'] : null)))),
        Text('Total: ${_money(cart['totals'])}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        FilledButton(onPressed: working ? null : _placeOrder, child: working ? const CircularProgressIndicator() : const Text('PLACE ORDER')),
      ]),
    );
  }
}
