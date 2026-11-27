import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_account_page.dart' show ArkCustomerApi;
import 'woo_store_api.dart';
import 'checkout_artwork.dart';

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
  bool formVisible = false;
  bool addressesLoading = true;
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
      if (mounted) setState(() { formVisible = true; addressesLoading = false; });
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
      addressesLoading = false;
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
        _persistSelectedAddress(savedAddresses.first);
      }
    });
  }

  Future<void> _persistSelectedAddress(Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('glowhit_selected_delivery_address', jsonEncode(value));
  }

  Future<void> _saveCurrentAddress() async {
    final value = address;
    final existingId = (widget.initialAddress['id'] ?? '').toString();
    if (existingId.isNotEmpty) value['id'] = widget.initialAddress['id'];
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
    await _persistSelectedAddress(value);
    if (mounted) setState(() {});
  }

  void _applySavedAddress(Map<String, dynamic> value) {
    for (final entry in fields.entries) {
      entry.value.text = (value[entry.key] ?? '').toString();
    }
    // A shipping quote belongs to the address that produced it. Never reuse
    // the previous address' rates/cart after selecting a different saved card.
    _persistSelectedAddress(value);
    setState(() {
      addressLabel = (value['label'] ?? 'Home').toString();
      selectedSavedAddress = savedAddresses.indexOf(value);
      rates = [];
      selectedRate = null;
      updatedCart = {};
      error = null;
    });
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
      await prefs.remove('glowhit_selected_delivery_address');
      if (mounted) setState(() { selectedSavedAddress = -1; formVisible = false; });
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
    if (mounted) setState(() {
      addressLabel = (chosen['label'] ?? 'Home').toString();
      formVisible = false;
      error = null;
      rates = [];
      selectedRate = null;
    });
    if (widget.embedded && widget.onAddressSaved != null) {
      widget.onAddressSaved!(chosen, cart);
    } else {
      Navigator.pop(context, {'address': chosen, 'cart': cart, 'shipping_selected': true});
    }
  }

  Future<void> _openEditAddressPage(Map<String, dynamic> item, int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DeliveryAddressPage(
          api: widget.api,
          customerToken: widget.customerToken,
          initialAddress: Map<String, dynamic>.from(item),
          formOnly: true,
        ),
      ),
    );
    if (result == null || !mounted || result['address'] is! Map) return;
    final updated = Map<String, dynamic>.from(result['address'] as Map);
    if (index >= 0 && index < savedAddresses.length) savedAddresses[index] = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedAddressKey, jsonEncode(savedAddresses));
    if (!mounted) return;
    setState(() {
      if (selectedSavedAddress == index) {
        for (final entry in fields.entries) { entry.value.text = (updated[entry.key] ?? '').toString(); }
        addressLabel = (updated['label'] ?? 'Home').toString();
      }
      error = null;
    });
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
        onChanged: (_) {
          if (rates.isNotEmpty || updatedCart.isNotEmpty) {
            setState(() { rates = []; selectedRate = null; updatedCart = {}; });
          }
        },
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF8F7FC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFE8E4F1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF51408F), width: 1.5)),
        ),
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
      title: Text(widget.formOnly ? ((widget.initialAddress['id'] ?? '').toString().isEmpty ? 'Add new address' : 'Edit address') : 'Delivery address'),
      centerTitle: false,
      actions: [if (!widget.formOnly) IconButton(tooltip: 'Add address', onPressed: busy ? null : _openNewAddressPage, icon: const Icon(Icons.add_location_alt_outlined))],
    ),
    body: Form(
      key: formKey,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF302052), Color(0xFF7655A8)]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: const Color(0xFF51408F).withValues(alpha: .16), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DELIVERY ADDRESS', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
              SizedBox(height: 7),
              Text('Where should we deliver?', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Choose a saved place or add a new one.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            Container(
              width: 82,
              height: 82,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: .88, end: 1),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutBack,
                    builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                    child: Image.memory(
                      CheckoutArtwork.fastDelivery,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                  if (widget.embedded && !widget.formOnly)
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: IconButton.filledTonal(
                        tooltip: 'Add address',
                        onPressed: busy ? null : _openNewAddressPage,
                        icon: const Icon(Icons.add_location_alt_rounded, size: 19),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF51408F),
                          minimumSize: const Size(34, 34),
                          maximumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        if (!widget.formOnly && savedAddresses.isNotEmpty) ...[
          ...List.generate(savedAddresses.length, (index) {
            final item = savedAddresses[index];
            final selected = selectedSavedAddress == index;
            final summary = ['address_1','address_2','city','state','postcode','country']
              .map((key) => item[key]).where((v) => v != null && v.toString().isNotEmpty).join(', ');
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: selected ? 3 : 0,
              shadowColor: const Color(0xFF51408F).withValues(alpha: .14),
              color: selected ? const Color(0xFFF4F0FF) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: selected ? const Color(0xFF51408F) : const Color(0xFFE8E4F1), width: selected ? 1.7 : 1),
              ),
              child: Column(children: [
                CheckboxListTile(
                  value: selected,
                  activeColor: const Color(0xFF51408F),
                  onChanged: busy ? null : (_) {
                    _applySavedAddress(item);
                    setState(() { selectedSavedAddress = index; formVisible = false; });
                  },
                  title: Row(children: [
                    Expanded(child: Text((item['label'] ?? 'Address ${index + 1}').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    if (selected) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE5F4FF), borderRadius: BorderRadius.circular(20)), child: const Text('SELECTED', style: TextStyle(color: Color(0xFF1769AA), fontSize: 10, fontWeight: FontWeight.w800))),
                  ]),
                  subtitle: Text(summary),
                  secondary: Icon((item['label'] == 'Office' || item['label'] == 'Work') ? Icons.work_outline : Icons.home_outlined, color: const Color(0xFF51408F)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(onPressed: busy ? null : () => _openEditAddressPage(item, index), icon: const Icon(Icons.edit_outlined, size: 17), label: const Text('EDIT')),
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
        if (addressesLoading && !widget.formOnly)
          const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator()))
        else if (!widget.formOnly && savedAddresses.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No saved addresses yet. Use the + icon above to add one.', textAlign: TextAlign.center)),
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
              if (!mounted) return;
              if (widget.formOnly) {
                Navigator.pop(context, {'address': <String, dynamic>{...address, if ((widget.initialAddress['id'] ?? '').toString().isNotEmpty) 'id': widget.initialAddress['id'], 'label': addressLabel}, 'saved': true});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address saved')));
              }
            } catch (e) {
              if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
            }
          },
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('SAVE THIS ADDRESS'),
        ),
        ],
        const SizedBox(height: 8),
        if (!widget.formOnly) SizedBox(height: 54, child: FilledButton(
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
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF51408F), elevation: 2, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: Text(widget.formOnly ? ((widget.initialAddress['id'] ?? '').toString().isEmpty ? 'SAVE ADDRESS' : 'UPDATE ADDRESS') : 'CONTINUE TO CONFIRM DETAILS', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .2)),
        )),
      ]),
    ),
  );
}
