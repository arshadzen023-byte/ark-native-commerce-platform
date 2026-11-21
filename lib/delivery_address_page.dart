import 'package:flutter/material.dart';
import 'woo_store_api.dart';

class DeliveryAddressPage extends StatefulWidget {
  const DeliveryAddressPage({super.key, required this.api, this.initialAddress = const {}});
  final WooStoreApi api;
  final Map<String, dynamic> initialAddress;
  @override
  State<DeliveryAddressPage> createState() => _DeliveryAddressPageState();
}

class _DeliveryAddressPageState extends State<DeliveryAddressPage> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  List<Map<String, dynamic>> rates = [];
  String? selectedRate;
  bool busy = false;
  String? error;
  Map<String, dynamic> updatedCart = {};

  @override
  void initState() {
    super.initState();
    fields = {
      'first_name': _controller('first_name'),
      'last_name': _controller('last_name'),
      'email': _controller('email'),
      'phone': _controller('phone'),
      'address_1': _controller('address_1'),
      'address_2': _controller('address_2'),
      'city': _controller('city'),
      'state': _controller('state'),
      'postcode': _controller('postcode'),
      'country': _controller('country', fallback: 'IN'),
    };
  }

  TextEditingController _controller(String key, {String fallback = ''}) =>
      TextEditingController(text: (widget.initialAddress[key] ?? fallback).toString());

  @override
  void dispose() {
    for (final controller in fields.values) { controller.dispose(); }
    super.dispose();
  }

  Map<String, dynamic> get address => fields.map((key, value) => MapEntry(key, value.text.trim()))
    ..['country'] = fields['country']!.text.trim().toUpperCase();

  Future<void> calculateShipping() async {
    if (!formKey.currentState!.validate()) return;
    setState(() { busy = true; error = null; });
    try {
      final value = address;
      final cart = await widget.api.updateCustomer(billing: value, shipping: value);
      final packages = (cart['shipping_rates'] as List? ?? cart['packages'] as List? ?? []);
      final found = <Map<String, dynamic>>[];
      for (final package in packages.whereType<Map>()) {
        final packageId = (package['package_id'] as num?)?.toInt() ?? 0;
        for (final rate in (package['shipping_rates'] as List? ?? []).whereType<Map>()) {
          found.add({...Map<String, dynamic>.from(rate), 'package_id': packageId});
        }
      }
      setState(() {
        updatedCart = cart;
        rates = found;
        selectedRate = found.where((r) => r['selected'] == true).map((r) => (r['rate_id'] ?? '').toString()).firstOrNull;
        if (found.isEmpty) error = 'No shipping method is available for this PIN code. Check the WooCommerce shipping zone and methods.';
      });
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectRate(Map<String, dynamic> rate) async {
    setState(() { busy = true; error = null; });
    try {
      final id = (rate['rate_id'] ?? rate['id'] ?? '').toString();
      final packageId = (rate['package_id'] as num?)?.toInt() ?? 0;
      final cart = await widget.api.selectShippingRate(packageId, id);
      setState(() { updatedCart = cart; selectedRate = id; });
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String ratePrice(Map<String, dynamic> rate) {
    final raw = int.tryParse('${rate['price'] ?? rate['cost'] ?? '0'}') ?? 0;
    final digits = (rate['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
    return '${rate['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
  }

  Widget field(String key, String label, {TextInputType type = TextInputType.text, bool required = true}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: fields[key],
        keyboardType: type,
        textCapitalization: key == 'email' ? TextCapitalization.none : TextCapitalization.words,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) return 'Please enter $label';
          if (key == 'email' && value != null && value.isNotEmpty && !value.contains('@')) return 'Enter a valid email';
          if (key == 'postcode' && value != null && value.isNotEmpty && value.length < 5) return 'Enter a valid PIN/postcode';
          return null;
        },
      ),
    );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delivery address')),
    body: Form(
      key: formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Where should we deliver?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: field('first_name', 'First name')), const SizedBox(width: 10), Expanded(child: field('last_name', 'Last name'))]),
        field('email', 'Email address', type: TextInputType.emailAddress),
        field('phone', 'Mobile number', type: TextInputType.phone),
        field('address_1', 'House / street / area'),
        field('address_2', 'Landmark (optional)', required: false),
        Row(children: [Expanded(child: field('city', 'City')), const SizedBox(width: 10), Expanded(child: field('state', 'State'))]),
        Row(children: [Expanded(child: field('postcode', 'PIN code', type: TextInputType.number)), const SizedBox(width: 10), Expanded(child: field('country', 'Country code'))]),
        OutlinedButton.icon(onPressed: busy ? null : calculateShipping, icon: const Icon(Icons.local_shipping_outlined), label: const Text('CALCULATE SHIPPING')),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        if (rates.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Available shipping methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...rates.map((rate) {
            final id = (rate['rate_id'] ?? rate['id'] ?? '').toString();
            return RadioListTile<String>(
              value: id, groupValue: selectedRate, onChanged: busy ? null : (_) => selectRate(rate),
              title: Text((rate['name'] ?? rate['method_title'] ?? id).toString()),
              subtitle: Text(ratePrice(rate)), activeColor: const Color(0xFF51408F),
            );
          }),
        ],
        const SizedBox(height: 20),
        SizedBox(height: 54, child: FilledButton(
          onPressed: busy ? null : () {
            if (!formKey.currentState!.validate()) return;
            if (rates.isNotEmpty && selectedRate == null) {
              setState(() => error = 'Please select a shipping method.');
              return;
            }
            Navigator.pop(context, {'address': address, 'cart': updatedCart, 'shipping_selected': selectedRate != null || rates.isEmpty});
          },
          child: const Text('CONTINUE TO PAYMENT', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
      ]),
    ),
  );
}
