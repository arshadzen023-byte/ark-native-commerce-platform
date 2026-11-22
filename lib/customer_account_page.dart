import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;
    return '${currency ?? '₹'}${amount.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> _asItems(dynamic value, [String? key]) {
    final raw = value is List ? value : (value is Map && value[key] is List ? value[key] as List : const []);
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains('deliver') || value.contains('complete')) return Colors.green;
    if (value.contains('cancel') || value.contains('fail') || value.contains('refund')) return Colors.red;
    if (value.contains('hold') || value.contains('pending')) return Colors.orange;
    return _accountPurple;
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
    final items = _asItems(data, widget.section == 'My Orders' ? 'orders' : widget.section == 'Downloads' ? 'downloads' : 'addresses');
    if (items.isEmpty) return Center(child: Text(widget.section == 'My Orders' ? 'No orders found yet.' : widget.section == 'Downloads' ? 'No downloadable products found.' : 'No saved addresses found.'));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) {
      final item = items[index];
      if (widget.section == 'My Orders') {
        final status = (item['status'] ?? 'pending').toString();
        final lineItems = (item['items'] as List? ?? item['line_items'] as List? ?? const []).whereType<Map>().toList();
        final lines = lineItems.map((e) => '${e['name'] ?? e['product_name']} × ${e['quantity']}').join(', ');
        final images = lineItems.map((e) => (e['image'] is Map ? (e['image'] as Map)['src'] : (e['image'] ?? e['image_url'] ?? '')).toString()).where((e) => e.isNotEmpty).toList();
        final id = (item['id'] ?? item['order_id'] ?? '').toString();
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: id.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(token: widget.token, order: item))),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: _accountPurple),
                const SizedBox(width: 8),
                Expanded(child: Text('Order #${item['number'] ?? id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                Text(_money(item['total'] ?? item['total_amount'], item['currency']), style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (images.isNotEmpty) SizedBox(width: 74, height: 74, child: Image.network(images.first, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined)))
                else const SizedBox(width: 74, height: 74, child: Icon(Icons.shopping_bag_outlined, size: 38)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(status.toUpperCase(), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(lines.isEmpty ? 'View order items' : lines, maxLines: 3, overflow: TextOverflow.ellipsis),
                ])),
                const Icon(Icons.chevron_right),
              ]),
              const Divider(height: 22),
              Row(children: [
                const Icon(Icons.local_shipping_outlined, size: 18, color: _accountPurple),
                const SizedBox(width: 6),
                const Text('Track order'),
                const Spacer(),
                TextButton(onPressed: id.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(token: widget.token, order: item))), child: const Text('VIEW DETAILS')),
              ]),
            ])),
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

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.token, required this.order});
  final String token;
  final Map<String, dynamic> order;
  @override State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Map<String, dynamic> order;
  bool loading = false;
  String? error;
  @override void initState() { super.initState(); order = Map<String, dynamic>.from(widget.order); refresh(); }
  Future<void> refresh() async {
    final id = (order['id'] ?? order['order_id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await ArkCustomerApi(widget.token).request('customer/orders/$id');
      final normalized = result is Map && result['order'] is Map ? result['order'] : result;
      if (normalized is Map && mounted) setState(() => order = Map<String, dynamic>.from(normalized));
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> cancel() async {
    final id = (order['id'] ?? order['order_id'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await ArkCustomerApi(widget.token).request('customer/orders/$id/cancel', method: 'POST', body: {'reason': 'Cancelled by customer'});
      if (result is Map && result['order'] is Map) order = Map<String, dynamic>.from(result['order']);
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancellation request sent.')));
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override Widget build(BuildContext context) {
    final status = (order['status'] ?? 'pending').toString();
    final lineItems = (order['items'] as List? ?? order['line_items'] as List? ?? const []).whereType<Map>().toList();
    final shipping = order['shipping'] is Map ? order['shipping'] as Map : const {};
    final canCancel = ['pending','on-hold','processing'].contains(status.toLowerCase());
    return Scaffold(
      appBar: AppBar(title: Text('Order #${order['number'] ?? order['id'] ?? ''}'), actions: [IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(status.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor(status), fontSize: 18)),
          const SizedBox(height: 12),
          for (final label in ['Order placed','Confirmed','Processing','Shipped','Out for delivery','Delivered'])
            Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(Icons.check_circle, size: 18, color: status.toLowerCase().contains('cancel') ? Colors.grey : _accountPurple), const SizedBox(width: 8), Text(label)])),
        ]))),
        const SizedBox(height: 8),
        const Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...lineItems.map((item) {
          final image = item['image'] is Map ? (item['image'] as Map)['src']?.toString() ?? '' : (item['image'] ?? item['image_url'] ?? '').toString();
          return Card(child: ListTile(
            leading: SizedBox(width: 64, height: 64, child: image.isEmpty ? const Icon(Icons.shopping_bag_outlined) : Image.network(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined))),
            title: Text((item['name'] ?? item['product_name'] ?? 'Product').toString()),
            subtitle: Text('Quantity: ${item['quantity'] ?? 1}'),
            trailing: Text('${order['currency'] ?? '₹'}${item['total'] ?? item['line_total'] ?? ''}'),
          ));
        }),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
          _detail('Total amount', '${order['currency'] ?? '₹'}${order['total'] ?? '—'}'),
          _detail('Payment method', (order['payment_method_title'] ?? order['payment_method'] ?? '—').toString()),
          _detail('Payment status', (order['payment_status'] ?? status).toString().toUpperCase()),
        ]))),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Delivery address', style: TextStyle(fontWeight: FontWeight.bold)),
          Text([shipping['first_name'], shipping['last_name'], shipping['address_1'], shipping['address_2'], shipping['city'], shipping['state'], shipping['postcode'], shipping['country']].where((v) => v != null && v.toString().isNotEmpty).join(', ')),
        ]))),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        if (canCancel) OutlinedButton.icon(onPressed: loading ? null : cancel, icon: const Icon(Icons.cancel_outlined), label: const Text('CANCEL ORDER')),
      ]),
    );
  }
  Widget _detail(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), const SizedBox(width: 8), Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold)))]));
}
