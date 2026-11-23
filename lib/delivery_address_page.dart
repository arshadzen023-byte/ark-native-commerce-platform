import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_account_page.dart';
import 'woo_store_api.dart';

class DeliveryAddressPage extends StatefulWidget {
  const DeliveryAddressPage({super.key, required this.api, this.initialAddress = const {}, this.customerToken, this.embedded = false, this.formOnly = false, this.onAddressSaved});
  final WooStoreApi api;
  final String? customerToken;
  final Map<String, dynamic> initialAddress;
  final bool embedded;
  final bool formOnly;
  final void Function(Map<String, dynamic> address, Map<String, dynamic> cart)? onAddressSaved;
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
  List<Map<String, dynamic>> savedAddresses = [];
  String addressLabel = 'Home';
  int selectedSavedAddress = -1;
  bool formVisible = true;
  static const _savedAddressKey = 'glowhit_saved_delivery_addresses';

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
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    if (widget.formOnly) {
      if (mounted) setState(() => formVisible = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedAddressKey);
    if (raw != null) {
      try { final list = jsonDecode(raw) as List; if (mounted) setState(() => savedAddresses = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()); } catch (_) { /* Ignore malformed local cache. */ }
    }
    final token = widget.customerToken;
    if (token != null) {
      try { final remote = await ArkCustomerApi(token).request('customer/addresses'); if (remote is List) { savedAddresses = remote.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); await prefs.setString(_savedAddressKey, jsonEncode(savedAddresses)); if (mounted) setState(() {}); } } catch (_) { /* Keep locally saved addresses available while offline. */ }
    }
    if (mounted) setState(() {
      if (savedAddresses.isEmpty && (widget.initialAddress['address_1'] ?? '').toString().trim().isNotEmpty) {
        savedAddresses.add({...widget.initialAddress, 'label': 'Default', 'id': 'default'});
      }
      formVisible = false;
      if (savedAddresses.isNotEmpty) {
        selectedSavedAddress = 0;
        for (final entry in fields.entries) {
          entry.value.text = (savedAddresses.first[entry.key] ?? '').toString();
        }
        addressLabel = (savedAddresses.first['label'] ?? 'Home').toString();
      }
    });
  }

  Future<void> _saveCurrentAddress() async {
    final value = address;
    value['label'] = addressLabel;
    if ((value['id'] ?? '').toString().isEmpty) {
      value['id'] = 'local-${DateTime.now().microsecondsSinceEpoch}';
    }
    final key = _savedAddressKey;
    final prefs = await SharedPreferences.getInstance();
    final index = savedAddresses.indexWhere((e) => e['address_1'] == value['address_1'] && e['postcode'] == value['postcode'] && e['first_name'] == value['first_name']);
    if (index >= 0) { savedAddresses[index] = value; } else { savedAddresses.add(value); }
    await prefs.setString(key, jsonEncode(savedAddresses));
    final token = widget.customerToken;
    if (token != null) {
      try {
        final remote = await ArkCustomerApi(token).request('customer/addresses', method: 'POST', body: value);
        final normalized = remote is List ? remote : (remote is Map && remote['addresses'] is List ? remote['addresses'] as List : const []);
        if (normalized.isNotEmpty) {
          savedAddresses = normalized.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
        await prefs.setString(key, jsonEncode(savedAddresses));
      } catch (e) {
        throw Exception('Address was kept on this device but could not be synced to your account: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
    selectedSavedAddress = savedAddresses.indexWhere((e) =>
      (e['address_1'] ?? '') == value['address_1'] &&
      (e['postcode'] ?? '') == value['postcode'] &&
      (e['first_name'] ?? '') == value['first_name']);
    if (mounted) setState(() {});
  }

  void _applySavedAddress(Map<String, dynamic> value) {
    for (final entry in fields.entries) {
      entry.value.text = (value[entry.key] ?? '').toString();
    }
    setState(() { addressLabel = (value['label'] ?? 'Home').toString(); selectedSavedAddress = savedAddresses.indexOf(value); });
  }

  Future<void> _deleteSelectedAddress() async {
    if (selectedSavedAddress < 0 || selectedSavedAddress >= savedAddresses.length) return;
    final value = savedAddresses[selectedSavedAddress];
    final id = (value['id'] ?? '').toString();
    setState(() { busy = true; error = null; });
    try {
      if (widget.customerToken != null && id.isNotEmpty) {
        await ArkCustomerApi(widget.customerToken!).request('customer/addresses', method: 'DELETE', query: {'id': id});
      }
      savedAddresses.removeAt(selectedSavedAddress);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedAddressKey, jsonEncode(savedAddresses));
      if (mounted) setState(() { selectedSavedAddress = -1; formVisible = savedAddresses.isEmpty; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openNewAddressPage() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryAddressPage(
          api: widget.api,
          customerToken: widget.customerToken,
          initialAddress: const {},
          formOnly: true,
        ),
      ),
    );
    if (result == null || !mounted || result['address'] is! Map) return;
    final chosen = Map<String, dynamic>.from(result['address'] as Map);
    for (final entry in fields.entries) {
      entry.value.text = (chosen[entry.key] ?? '').toString();
    }
    final cart = result['cart'] is Map
        ? Map<String, dynamic>.from(result['cart'] as Map)
        : await widget.api.getCart();
    final existing = savedAddresses.indexWhere((item) =>
        item['address_1'] == chosen['address_1'] &&
        item['postcode'] == chosen['postcode'] &&
        item['first_name'] == chosen['first_name']);
    if (existing >= 0) {
      savedAddresses[existing] = chosen;
      selectedSavedAddress = existing;
    } else {
      savedAddresses.add(chosen);
      selectedSavedAddress = savedAddresses.length - 1;
    }
    updatedCart = cart;
    if (mounted) setState(() { addressLabel = (chosen['label'] ?? 'Home').toString(); formVisible = false; error = null; });
    if (widget.embedded && widget.onAddressSaved != null) {
      widget.onAddressSaved!(chosen, cart);
    } else {
      Navigator.pop(context, {'address': chosen, 'cart': cart, 'shipping_selected': true});
    }
  }

  TextEditingController _controller(String key, {String fallback = ''}) =>
      TextEditingController(text: (widget.initialAddress[key] ?? fallback).toString());

  @override
  void dispose() {
    for (final controller in fields.values) { controller.dispose(); }
    super.dispose();
  }

  Map<String, dynamic> get address => fields.map((key, controller) => MapEntry(key, controller.text.trim()))
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
    appBar: widget.embedded ? null : AppBar(
      title: Text(widget.formOnly ? 'Add new address' : 'Delivery address'),
      centerTitle: false,
    ),
    body: Form(
      key: formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Where should we deliver?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (!widget.formOnly && savedAddresses.isNotEmpty) ...[
          ...List.generate(savedAddresses.length, (index) {
            final item = savedAddresses[index];
            final selected = selectedSavedAddress == index;
            final summary = ['address_1','address_2','city','state','postcode','country']
              .map((key) => item[key]).where((v) => v != null && v.toString().isNotEmpty).join(', ');
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: selected ? const Color(0xFF51408F) : Colors.black12, width: selected ? 1.5 : 1),
              ),
              child: Column(children: [
                CheckboxListTile(
                  value: selected,
                  activeColor: const Color(0xFF51408F),
                  onChanged: busy ? null : (_) {
                    _applySavedAddress(item);
                    setState(() { selectedSavedAddress = index; formVisible = false; });
                  },
                  title: Text((item['label'] ?? 'Address ${index + 1}').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(summary),
                  secondary: Icon((item['label'] == 'Office' || item['label'] == 'Work') ? Icons.work_outline : Icons.home_outlined, color: const Color(0xFF51408F)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(onPressed: busy ? null : () {
                      _applySavedAddress(item);
                      setState(() { selectedSavedAddress = index; formVisible = true; });
                    }, icon: const Icon(Icons.edit_outlined, size: 17), label: const Text('EDIT')),
                    TextButton.icon(onPressed: busy ? null : () async {
                      setState(() => selectedSavedAddress = index);
                      await _deleteSelectedAddress();
                    }, icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red), label: const Text('DELETE', style: TextStyle(color: Colors.red))),
                  ]),
                ),
              ]),
            );
          }),
        ],
        if (!widget.formOnly) SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: busy ? null : _openNewAddressPage,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('ADD NEW ADDRESS'),
        )),
        if (formVisible) ...[
        DropdownButtonFormField<String>(
          value: addressLabel,
          decoration: const InputDecoration(labelText: 'Address type', border: OutlineInputBorder()),
          items: const [DropdownMenuItem(value: 'Home', child: Text('Home')), DropdownMenuItem(value: 'Work', child: Text('Work')), DropdownMenuItem(value: 'Other', child: Text('Other'))],
          onChanged: (value) { if (value != null) setState(() => addressLabel = value); },
        ),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: field('first_name', 'First name')), const SizedBox(width: 10), Expanded(child: field('last_name', 'Last name'))]),
        field('email', 'Email address', type: TextInputType.emailAddress),
        field('phone', 'Mobile number', type: TextInputType.phone),
        field('address_1', 'House / street / area'),
        field('address_2', 'Landmark (optional)', required: false),
        Row(children: [Expanded(child: field('city', 'City')), const SizedBox(width: 10), Expanded(child: field('state', 'State'))]),
        Row(children: [Expanded(child: field('postcode', 'PIN code', type: TextInputType.number)), const SizedBox(width: 10), Expanded(child: field('country', 'Country code'))]),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy ? null : () async {
            if (!formKey.currentState!.validate()) return;
            try {
              await _saveCurrentAddress();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address saved')));
            } catch (e) {
              if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
            }
          },
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('SAVE THIS ADDRESS'),
        ),
        ],
        const SizedBox(height: 8),
        SizedBox(height: 54, child: FilledButton(
          onPressed: busy ? null : () async {
            if (!formVisible && selectedSavedAddress < 0) {
              setState(() => error = 'Please add or select a delivery address.');
              return;
            }
            if (formVisible && !formKey.currentState!.validate()) return;
            try {
              await _saveCurrentAddress();
              if (rates.isEmpty) { await calculateShipping(); return; }
              final chosen = <String, dynamic>{...address, 'label': addressLabel};
              if (selectedSavedAddress >= 0 && selectedSavedAddress < savedAddresses.length) {
                chosen['id'] = savedAddresses[selectedSavedAddress]['id'] ?? '';
              }
              final chosenCart = updatedCart.isNotEmpty ? updatedCart : await widget.api.getCart();
              if (!mounted) return;
              if (widget.embedded && widget.onAddressSaved != null) {
                widget.onAddressSaved!(chosen, chosenCart);
              } else {
                Navigator.pop(context, {'address': chosen, 'cart': chosenCart, 'shipping_selected': selectedRate != null || rates.isEmpty});
              }
            } catch (e) {
              if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
            }
          },
          child: Text(widget.formOnly ? 'SAVE ADDRESS & CONTINUE' : 'CONTINUE TO CONFIRM DETAILS', style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ]),
    ),
  );
}
