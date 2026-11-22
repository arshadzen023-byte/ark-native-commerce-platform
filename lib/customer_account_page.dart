import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'woo_store_api.dart';

const _accountPurple = Color(0xFF51408F);

class ArkCustomerApi {
  ArkCustomerApi(this.token, {this.baseUrl = 'https://pluginstore.shop'});
  final String token;
  final String baseUrl;
  Future<dynamic> request(String path, {String method = 'GET', Map<String, dynamic>? body, Map<String, String>? query}) async {
    final uri = Uri.parse(baseUrl).resolve('wp-json/ark-native/v1/$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json', 'Authorization': 'Bearer $token'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final client = http.Client();
    try {
      final response = await client.send(req).timeout(const Duration(seconds: 20));
      final result = await http.Response.fromStream(response);
      dynamic data;
      try { data = result.body.isEmpty ? null : jsonDecode(result.body); }
      catch (_) { throw Exception('The store returned an invalid response (${result.statusCode}).'); }
      if (result.statusCode < 200 || result.statusCode >= 300) {
        final message = data is Map ? (data['message'] ?? data['code']) : data;
        throw Exception(message?.toString() ?? 'Request failed (${result.statusCode}).');
      }
      return data;
    } finally { client.close(); }
  }
}

class CustomerSectionPage extends StatefulWidget {
  const CustomerSectionPage({super.key, required this.token, required this.section});
  final String token;
  final String section;
  @override State<CustomerSectionPage> createState() => _CustomerSectionPageState();
}

class _CustomerSectionPageState extends State<CustomerSectionPage> {
  late final ArkCustomerApi api;
  bool loading = true, saving = false;
  String? error;
  dynamic data;
  final fields = <String, TextEditingController>{};
  @override
  void initState() { super.initState(); api = ArkCustomerApi(widget.token); load(); }
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
  List<Map<String, dynamic>> _asMapList(dynamic value, String key) {
    dynamic list = value;
    if (value is Map) {
      list = value[key] ?? value['data'] ?? value['items'];
      if (list is Map && list[key] is List) list = list[key];
      if (list is Map && key == 'addresses') {
        final shipping = list['shipping'];
        final billing = list['billing'];
        final candidate = shipping is Map && (shipping['address_1'] ?? '').toString().isNotEmpty
            ? shipping
            : billing;
        list = candidate is Map && (candidate['address_1'] ?? '').toString().isNotEmpty
            ? [candidate]
            : [];
      }
    }
    if (list is! List) return [];
    return list.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  String get path => switch (widget.section) {
    'My Orders' => 'customer/orders',
    'Downloads' => 'customer/downloads',
    'Saved Addresses' => 'customer/addresses',
    _ => 'customer/me',
  };
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await api.request(path);
      if (!mounted) return;
      data = result;
      if (widget.section == 'Edit Profile' && result is Map) {
        for (final key in ['display_name', 'email', 'first_name', 'last_name']) {
          fields.putIfAbsent(key, () => TextEditingController(text: (result[key] ?? '').toString()));
        }
        final billing = result['billing'] is Map ? result['billing'] as Map : const {};
        fields.putIfAbsent('billing_phone', () => TextEditingController(text: (billing['phone'] ?? '').toString()));
      }
      setState(() => loading = false);
    } catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; }); }
  }
  Future<void> saveProfile() async {
    setState(() => saving = true);
    try {
      await api.request('customer/me', method: 'PUT', body: {for (final e in fields.entries) e.key: e.value.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      await load();
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => saving = false); }
  }
  String _money(dynamic value, dynamic currency) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '${currency ?? '₹'}0.00';
    // The ARK bridge already formats WooCommerce totals (for example ₹1,122.00).
    // Preserve those strings instead of parsing them as zero.
    if (RegExp(r'[^0-9.,-]').hasMatch(raw)) return raw;
    final amount = double.tryParse(raw.replaceAll(',', '')) ?? 0;
    final symbol = currency?.toString() == 'INR' ? '₹' : (currency ?? '₹').toString();
    return '$symbol${amount.toStringAsFixed(2)}';
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.section), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('RETRY'))])))
      : _body(),
  );
  Widget _body() {
    if (widget.section == 'Edit Profile') {
      return ListView(padding: const EdgeInsets.all(16), children: [
        for (final key in ['display_name', 'email', 'first_name', 'last_name', 'billing_phone'])
          Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: fields[key], keyboardType: key == 'email' ? TextInputType.emailAddress : TextInputType.text, decoration: InputDecoration(labelText: switch (key) { 'display_name' => 'Display name', 'billing_phone' => 'Mobile number', _ => key.replaceAll('_', ' ').toUpperCase() }, border: const OutlineInputBorder()))),
        FilledButton(onPressed: saving ? null : saveProfile, child: saving ? const CircularProgressIndicator() : const Text('SAVE PROFILE')),
      ]);
    }
    final responseKey = widget.section == 'My Orders' ? 'orders' : widget.section == 'Downloads' ? 'downloads' : 'addresses';
    final items = _asMapList(data, responseKey);
    if (items.isEmpty) {
      if (widget.section == 'My Orders') {
        return Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.receipt_long_outlined, size: 52, color: _accountPurple),
            const SizedBox(height: 12),
            const Text('No orders linked to this account yet.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Guest orders appear here when their checkout billing email matches your signed-in account email.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('REFRESH ORDERS')),
          ]),
        ));
      }
      return Center(child: Text(widget.section == 'Downloads' ? 'No downloadable products found.' : 'No saved addresses found.'));
    }
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) {
      final item = items[index];
      if (item is! Map) return const SizedBox.shrink();
      if (widget.section == 'My Orders') {
        final lines = (item['items'] as List? ?? []).whereType<Map>().map((e) => '${e['name']} × ${e['quantity']}').join(', ');
        final orderItems = (item['items'] as List? ?? []).whereType<Map>().toList();
        final firstItem = orderItems.isEmpty ? null : orderItems.first;
        final image = firstItem?['image']?.toString() ?? '';
        final status = (item['status_label'] ?? item['status'] ?? 'Order received').toString();
        final statusColor = switch ((item['status_key'] ?? item['status'] ?? '').toString().toLowerCase()) {
          'completed' => Colors.green,
          'cancelled' || 'failed' || 'refunded' => Colors.red,
          'on-hold' || 'pending' => Colors.orange,
          _ => _accountPurple,
        };
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _CustomerOrderDetailPage(api: api, orderId: int.tryParse('${item['id']}') ?? 0),
            )).then((_) => load()),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.receipt_long, color: _accountPurple),
                  const SizedBox(width: 9),
                  Expanded(child: Text('Order #${item['number'] ?? item['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  Text(_money(item['total'], item['currency']), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: image.isEmpty ? const Icon(Icons.shopping_bag_outlined, color: _accountPurple) : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text((item['date_created'] ?? item['date'] ?? '').toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(lines, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const Icon(Icons.chevron_right),
                ]),
                const Divider(height: 20),
                Row(children: [
                  const Icon(Icons.local_shipping_outlined, size: 18, color: _accountPurple),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('Track order • View details', style: TextStyle(fontWeight: FontWeight.w600, color: _accountPurple))),
                  if (item['can_cancel'] == true) const Text('Cancel available', style: TextStyle(fontSize: 11, color: Colors.orange)),
                ]),
              ]),
            ),
          ),
        );
      }
      if (widget.section == 'Downloads') {
        return Card(child: ListTile(leading: const Icon(Icons.download, color: _accountPurple), title: Text((item['download_name'] ?? item['product_name'] ?? 'Download').toString()), subtitle: Text('Remaining: ${item['downloads_remaining'] ?? '—'}'), trailing: IconButton(icon: const Icon(Icons.open_in_new), onPressed: () { final uri = Uri.tryParse((item['download_url'] ?? '').toString()); if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication); })));
      }
      return Card(child: ListTile(leading: const Icon(Icons.location_on_outlined, color: _accountPurple), title: Text((item['label'] ?? 'Address').toString()), subtitle: Text(['address_1','address_2','city','state','postcode','country'].map((k) => item[k]).where((v) => v != null && v.toString().isNotEmpty).join(', '))));
    });
  }
}

class _CustomerOrderDetailPage extends StatefulWidget {
  const _CustomerOrderDetailPage({required this.api, required this.orderId});
  final ArkCustomerApi api;
  final int orderId;
  @override State<_CustomerOrderDetailPage> createState() => _CustomerOrderDetailPageState();
}

class _CustomerOrderDetailPageState extends State<_CustomerOrderDetailPage> {
  Map<String, dynamic>? order;
  bool loading = true, cancelling = false;
  String? error;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.api.request('customer/orders/${widget.orderId}');
      if (!mounted) return;
      setState(() { order = result is Map ? Map<String, dynamic>.from(result) : null; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }
  Future<void> requestReturn() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Request a return'),
      content: TextField(controller: controller, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Reason for return', hintText: 'Tell us what went wrong', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('SUBMIT REQUEST'))],
    ));
    controller.dispose();
    if (reason == null || reason.trim().length < 5) return;
    try {
      await widget.api.request('customer/orders/${widget.orderId}/return', method: 'POST', body: {'reason': reason.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return request sent to the store for review.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }
  Future<void> cancel() async {
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Cancel this order?'),
      content: const Text('The store will be notified. If payment was already captured, any refund must be reviewed and processed by the store.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP ORDER')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CANCEL ORDER'))],
    ));
    if (ok != true) return;
    setState(() => cancelling = true);
    try {
      await widget.api.request('customer/orders/${widget.orderId}/cancel', method: 'POST', body: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancellation submitted.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => cancelling = false); }
  }
  String money(dynamic v, dynamic currency) {
    final raw = (v ?? '').toString().trim();
    if (raw.isEmpty) return '${currency ?? '₹'}0.00';
    if (RegExp(r'[^0-9.,-]').hasMatch(raw)) return raw;
    final symbol = currency?.toString() == 'INR' ? '₹' : (currency ?? '₹').toString();
    return '$symbol${(double.tryParse(raw.replaceAll(',', '')) ?? 0).toStringAsFixed(2)}';
  }

  Future<void> buyAgain() async {
    final items = (order?['items'] as List? ?? []).whereType<Map>().toList();
    if (items.isEmpty) return;
    final woo = WooStoreApi();
    var added = 0;
    try {
      for (final item in items) {
        final id = int.tryParse('${item['product_id'] ?? ''}') ?? 0;
        final quantity = int.tryParse('${item['quantity'] ?? 1}') ?? 1;
        if (id > 0) {
          await woo.addItem(id, quantity: quantity.clamp(1, 99).toInt());
          added++;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added > 0 ? '$added product(s) added to your cart.' : 'These products are no longer available.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Order #${widget.orderId}'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('RETRY'))])))
      : order == null ? const Center(child: Text('Order details unavailable.')) : _content(),
  );
  Widget _content() {
    final o = order!;
    final items = (o['items'] as List? ?? []).whereType<Map>().toList();
    final timeline = (o['timeline'] as List? ?? []).whereType<Map>().toList();
    final shipping = o['shipping'] is Map ? o['shipping'] as Map : const {};
    final addressParts = ['first_name','last_name','address_1','address_2','city','state','postcode','country'].map((k) => shipping[k]?.toString() ?? '').where((v) => v.isNotEmpty).toList();
    final address = addressParts.isNotEmpty ? addressParts.join(', ') : (shipping['address']?.toString() ?? '');
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((o['status_label'] ?? o['status'] ?? 'Order received').toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accountPurple)),
        const SizedBox(height: 4), Text('Placed on ${o['date_created'] ?? '—'}', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        for (final step in timeline) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
          Icon(step['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: step['done'] == true ? Colors.green : Colors.grey),
          const SizedBox(width: 10), Expanded(child: Text((step['label'] ?? '').toString())),
        ])),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        for (final item in items) ListTile(contentPadding: EdgeInsets.zero, leading: SizedBox(width: 54, height: 54, child: item['image'] == null || item['image'].toString().isEmpty ? const Icon(Icons.shopping_bag_outlined) : Image.network(item['image'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined))), title: Text(item['name']?.toString() ?? 'Product'), subtitle: Text('Qty: ${item['quantity'] ?? 1}'), trailing: Text(money(item['total'], o['currency']))),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payment summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        _line('Subtotal', money(o['subtotal'], o['currency'])),
        _line('Shipping', money(o['shipping_total'], o['currency'])),
        _line('Discount', money(o['discount_total'], o['currency'])),
        _line('Tax', money(o['tax_total'], o['currency'])),
        const Divider(), _line('Order total', money(o['total'], o['currency']), bold: true),
        const SizedBox(height: 8), Text('Payment: ${o['payment_method'] ?? '—'}'),
        Text('Payment status: ${o['payment_status'] ?? '—'}'),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8), Text(address.isEmpty ? 'Address not available' : address),
        if ((shipping['phone'] ?? '').toString().isNotEmpty) Text('Phone: ${shipping['phone']}'),
      ]))),
      if (items.isNotEmpty) SizedBox(height: 52, child: FilledButton.icon(onPressed: buyAgain, icon: const Icon(Icons.shopping_bag_outlined), label: const Text('BUY AGAIN'))),
      if (o['can_cancel'] == true) SizedBox(height: 52, child: OutlinedButton.icon(onPressed: cancelling ? null : cancel, icon: cancelling ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cancel_outlined), label: const Text('CANCEL ORDER'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red))),
      if ((o['status_key'] ?? o['status'] ?? '').toString() == 'completed' && (o['return_request_status'] ?? '').toString() != 'pending')
        SizedBox(height: 52, child: OutlinedButton.icon(onPressed: requestReturn, icon: const Icon(Icons.assignment_return_outlined), label: const Text('REQUEST RETURN'))),
      if ((o['return_request_status'] ?? '').toString() == 'pending')
        const ListTile(leading: Icon(Icons.hourglass_top, color: Colors.orange), title: Text('Return request awaiting store review')),
      const SizedBox(height: 20),
    ]);
  }
  Widget _line(String label, String value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))]));
}
