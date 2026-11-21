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
    final items = data is List ? data as List : const [];
    if (items.isEmpty) return Center(child: Text(widget.section == 'My Orders' ? 'No orders found yet.' : widget.section == 'Downloads' ? 'No downloadable products found.' : 'No saved addresses found.'));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) {
      final item = items[index];
      if (item is! Map) return const SizedBox.shrink();
      if (widget.section == 'My Orders') {
        final lines = (item['items'] as List? ?? []).whereType<Map>().map((e) => '${e['name']} × ${e['quantity']}').join(', ');
        return Card(child: ListTile(leading: const Icon(Icons.receipt_long, color: _accountPurple), title: Text('Order #${item['number'] ?? item['id']}'), subtitle: Text('${item['status'] ?? ''} • ${item['date_created'] ?? ''}\n$lines'), isThreeLine: true, trailing: Text(_money(item['total'], item['currency']), style: const TextStyle(fontWeight: FontWeight.bold))));
      }
      if (widget.section == 'Downloads') {
        return Card(child: ListTile(leading: const Icon(Icons.download, color: _accountPurple), title: Text((item['download_name'] ?? item['product_name'] ?? 'Download').toString()), subtitle: Text('Remaining: ${item['downloads_remaining'] ?? '—'}'), trailing: IconButton(icon: const Icon(Icons.open_in_new), onPressed: () { final uri = Uri.tryParse((item['download_url'] ?? '').toString()); if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication); })));
      }
      return Card(child: ListTile(leading: const Icon(Icons.location_on_outlined, color: _accountPurple), title: Text((item['label'] ?? 'Address').toString()), subtitle: Text(['address_1','address_2','city','state','postcode','country'].map((k) => item[k]).where((v) => v != null && v.toString().isNotEmpty).join(', '))));
    });
  }
}
