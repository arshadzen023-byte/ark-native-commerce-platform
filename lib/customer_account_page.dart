import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
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

    Future<http.Response> send(Uri target) async {
      final req = http.Request(method, target)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final client = http.Client();
      try {
        final response = await client.send(req).timeout(const Duration(seconds: 20));
        return await http.Response.fromStream(response).timeout(const Duration(seconds: 20));
      } finally { client.close(); }
    }

    final primary = await send(uri);
    // Retry WordPress' canonical REST query form only for rewrite-related
    // 404/405 responses. Do not retry 401/403: authentication and WAF blocks
    // must remain visible and must never be bypassed by a fallback.
    final result = (primary.statusCode == 404 || primary.statusCode == 405)
      ? await send(Uri.parse(baseUrl).replace(
          path: '/',
          queryParameters: {'rest_route': '/ark-native/v1/$path', ...?query},
        ))
      : primary;
    dynamic data;
    try { data = result.body.isEmpty ? null : jsonDecode(result.body); }
    catch (_) { throw Exception('The store returned an invalid response (${result.statusCode}).'); }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      final message = data is Map ? (data['message'] ?? data['code']) : data;
      throw Exception(message?.toString() ?? 'Request failed (${result.statusCode}).');
    }
    return data;
  }
}

class CustomerSectionPage extends StatefulWidget {
  const CustomerSectionPage({super.key, required this.token, required this.section, this.floatingActionButton});
  final String token;
  final String section;
  final Widget? floatingActionButton;
  @override State<CustomerSectionPage> createState() => _CustomerSectionPageState();
}

class _CustomerSectionPageState extends State<CustomerSectionPage> {
  late final ArkCustomerApi api;
  bool loading = true, saving = false;
  String? error;
  dynamic data;
  final fields = <String, TextEditingController>{};
  final orderSearch = TextEditingController();
  String orderFilter = 'All';
  @override
  void initState() { super.initState(); api = ArkCustomerApi(widget.token); load(); }
  @override
  void dispose() { orderSearch.dispose(); for (final c in fields.values) { c.dispose(); } super.dispose(); }
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
    if (value == null || value.toString().trim().isEmpty) return '—';
    final amount = double.tryParse(value.toString().replaceAll(',', ''));
    if (amount == null) return value.toString();
    final code = (currency ?? '₹').toString();
    final symbol = code.toUpperCase() == 'INR' ? '₹' : code;
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> _asItems(dynamic value, [String? key]) {
    final raw = value is List ? value : (value is Map && value[key] is List ? value[key] as List : const []);
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.section), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null
      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('RETRY'))])))
      : _body(),
    floatingActionButton: widget.floatingActionButton,
  );
  Widget _body() {
    if (widget.section == 'Edit Profile') {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 28), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF33205F), Color(0xFF7655A8)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 34),
            SizedBox(height: 12),
            Text('Your profile, your details', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Keep your contact information up to date for smooth deliveries.', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .45))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              for (final entry in [
                ('display_name', 'Display name', Icons.badge_outlined),
                ('first_name', 'First name', Icons.person_outline),
                ('last_name', 'Last name', Icons.person_outline),
                ('email', 'Email address', Icons.email_outlined),
                ('billing_phone', 'Mobile number', Icons.phone_outlined),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: TextField(
                    controller: fields[entry.$1],
                    keyboardType: entry.$1 == 'email' ? TextInputType.emailAddress : entry.$1 == 'billing_phone' ? TextInputType.phone : TextInputType.text,
                    decoration: material.InputDecoration(
                      labelText: entry.$2,
                      prefixIcon: Icon(entry.$3, color: _accountPurple),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: saving ? null : saveProfile,
                icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: const Text('SAVE CHANGES'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              )),
            ]),
          ),
        ),
      ]);
    }
    final items = _asItems(data, widget.section == 'My Orders' ? 'orders' : widget.section == 'Downloads' ? 'downloads' : 'addresses');
    if (widget.section == 'Saved Addresses') return _addressesBody(items);
    if (widget.section == 'My Orders') return _ordersBody(items);
    if (items.isEmpty) return Center(child: Text(widget.section == 'Downloads' ? 'No downloadable products found.' : 'No saved addresses found.'));
    return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) {
      final item = items[index];
      if (widget.section == 'Downloads') {
        final name = (item['product_name'] ?? item['name'] ?? item['download_name'] ?? 'Download').toString();
        final fileName = (item['file_name'] ?? '').toString();
        final url = (item['download_url'] ?? '').toString();
        final remaining = (item['downloads_remaining'] ?? '—').toString();
        final expiry = (item['access_expires'] ?? '').toString();
        return Card(
          margin: const EdgeInsets.only(bottom: 13),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .45))),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: _accountPurple.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.file_download_outlined, color: _accountPurple, size: 29)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  if (fileName.isNotEmpty) Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ])),
              ]),
              const SizedBox(height: 13),
              Wrap(spacing: 8, runSpacing: 7, children: [
                Chip(avatar: const Icon(Icons.download_done, size: 16), label: Text('Remaining: $remaining')),
                if (item['order_id'] != null) Chip(avatar: const Icon(Icons.receipt_long, size: 16), label: Text('Order #${item['order_id']}')),
              ]),
              if (expiry.isNotEmpty && expiry != '0') Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Access expires: $expiry', style: Theme.of(context).textTheme.bodySmall)),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: url.isEmpty ? null : () async {
                  final uri = Uri.tryParse(url);
                  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download link is invalid.')));
                    return;
                  }
                  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the download link.')));
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('DOWNLOAD FILE'),
              )),
            ]),
          ),
        );
      }
      return Card(child: ListTile(leading: const Icon(Icons.location_on_outlined, color: _accountPurple), title: Text((item['label'] ?? 'Address').toString()), subtitle: Text(['address_1','address_2','city','state','postcode','country'].map((k) => item[k]).where((v) => v != null && v.toString().isNotEmpty).join(', '))));
    });
  }


  Widget _addressesBody(List<Map<String, dynamic>> addresses) {
    String addressText(Map<String, dynamic> item) => [
      item['address_1'], item['address_2'], item['city'], item['state'],
      item['postcode'], item['country'],
    ].where((v) => v != null && v.toString().trim().isNotEmpty)
      .map((v) => v.toString().trim()).join(', ');

    Future<void> openForm([Map<String, dynamic>? item]) async {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => SavedAddressFormPage(
          token: widget.token,
          initialAddress: item,
        )),
      );
      if (saved == true && mounted) await load();
    }

    Future<void> removeAddress(Map<String, dynamic> item) async {
      final id = (item['id'] ?? '').toString();
      if (id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This address has no server ID. Refresh addresses and try again.')),
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete address?'),
          content: Text('Remove “${item['label'] ?? 'Address'}” from your saved addresses?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('KEEP')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('DELETE'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() { saving = true; error = null; });
      try {
        await api.request('customer/addresses', method: 'DELETE', query: {'id': id});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address deleted from your account.')));
        await load();
      } catch (e) {
        if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => saving = false);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF33205F), Color(0xFF7655A8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(23),
            boxShadow: [BoxShadow(color: _accountPurple.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('YOUR DELIVERY PLACES', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
              SizedBox(height: 9),
              Text('Saved Addresses', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('Add, edit or remove the places where you shop.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            const SizedBox(width: 12),
            Container(
              width: 62, height: 62,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 34),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: saving ? null : () => openForm(),
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('ADD NEW ADDRESS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .4)),
            style: FilledButton.styleFrom(
              backgroundColor: _accountPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (addresses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .5)),
            ),
            child: const Column(children: [
              Icon(Icons.location_off_outlined, color: _accountPurple, size: 42),
              SizedBox(height: 10),
              Text('No saved addresses yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(height: 5),
              Text('Add your first delivery address to make checkout faster.', textAlign: TextAlign.center),
            ]),
          ),
        for (final item in addresses) ...[
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .55)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(color: _accountPurple.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
                    child: Icon(
                      (item['label'] ?? '').toString().toLowerCase() == 'work' ? Icons.work_outline_rounded : Icons.home_outlined,
                      color: _accountPurple, size: 25,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((item['label'] ?? 'Address').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    if ((item['first_name'] ?? '').toString().isNotEmpty || (item['last_name'] ?? '').toString().isNotEmpty)
                      Text('${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'.trim(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ])),
                  const Icon(Icons.verified_user_outlined, color: _accountPurple, size: 19),
                ]),
                const SizedBox(height: 12),
                Text(addressText(item), style: const TextStyle(height: 1.45, fontSize: 13.5)),
                if ((item['phone'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Row(children: [
                    const Icon(Icons.call_outlined, size: 16, color: _accountPurple),
                    const SizedBox(width: 7),
                    Text(item['phone'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ],
                const Divider(height: 22),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: saving ? null : () => openForm(item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('EDIT'),
                    style: OutlinedButton.styleFrom(foregroundColor: _accountPurple, side: BorderSide(color: _accountPurple.withValues(alpha: .45))),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: saving ? null : () => removeAddress(item),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('DELETE'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade600, side: BorderSide(color: Colors.red.shade200)),
                  )),
                ]),
              ]),
            ),
          ),
        ],
        if (saving) const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  String _normalStatus(dynamic raw) {
    final s = (raw ?? 'pending').toString().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-').replaceFirst(RegExp(r'^wc-'), '');
    if (s == 'on-hold' || s == 'hold') return 'hold';
    if (['pending','pending-payment','payment-pending','awaiting-verification'].contains(s)) return 'payment-pending';
    if (['outfordelivery','out-of-delivery','out-for-delivery'].contains(s)) return 'out-for-delivery';
    if (['complete','completed','delivered'].contains(s)) return 'delivered';
    if (s == 'draft') return 'draft';
    if (s == 'cancelled' || s == 'canceled') return 'cancelled';
    if (s == 'failed' || s == 'refunded') return s;
    return s;
  }

  String _orderTotal(Map<String, dynamic> item) {
    final candidates = [item['total'], item['total_amount'], item['order_total'], item['total_price'], item['amount_total'], item['grand_total'], item['amount']];
    dynamic value;
    for (final candidate in candidates) {
      if (candidate == null || candidate.toString().trim().isEmpty) continue;
      final parsed = double.tryParse(candidate.toString().replaceAll(',', ''));
      if (parsed != null && parsed != 0) { value = candidate; break; }
      value ??= candidate;
    }
    value ??= item['formatted_total'];
    if (value == null) return '—';
    if (value is String && value.contains(RegExp(r'[^0-9., -]'))) return value;
    return _money(value, item['currency_symbol'] ?? item['currency']);
  }

  String _shortTitle(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 44) return clean;
    return '${clean.substring(0, 41).trimRight()}…';
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    if (orderFilter == 'All') return true;
    final status = _normalStatus(item['status_key'] ?? item['status']);
    switch (orderFilter) {
      case 'Draft': return status == 'draft';
      case 'Hold': return status == 'hold';
      case 'Payment pending': return status == 'payment-pending';
      case 'Processing': return status == 'processing';
      case 'Shipped': return status == 'shipped';
      case 'Out for delivery': return status == 'out-for-delivery';
      case 'Delivered': return status == 'delivered';
      case 'Cancelled': return status == 'cancelled';
      case 'Failed': return status == 'failed' || status == 'refunded';
      default: return true;
    }
  }

  Widget _ordersBody(List<Map<String, dynamic>> allItems) {
    final query = orderSearch.text.trim().toLowerCase();
    final filtered = allItems.where((item) {
      if (!_matchesFilter(item)) return false;
      if (query.isEmpty) return true;
      final id = (item['number'] ?? item['id'] ?? item['order_id'] ?? '').toString();
      final names = ((item['items'] ?? item['line_items']) is List
          ? ((item['items'] ?? item['line_items']) as List).whereType<Map>().map((e) => e['name'] ?? e['product_name'] ?? '').join(' ')
          : '');
      final haystack = '$id $names ${item['status'] ?? ''} ${item['payment_method_title'] ?? item['payment_method'] ?? ''}'.toLowerCase();
      return haystack.contains(query);
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: TextField(
          controller: orderSearch,
          onChanged: (_) => setState(() {}),
          decoration: material.InputDecoration(
            hintText: 'Search order number or product',
            prefixIcon: const Icon(Icons.search, color: _accountPurple),
            suffixIcon: orderSearch.text.isEmpty ? null : IconButton(onPressed: () { orderSearch.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final label in ['All','Draft','Hold','Payment pending','Processing','Shipped','Out for delivery','Delivered','Cancelled','Failed'])
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(label),
                  selected: orderFilter == label,
                  onSelected: (_) => setState(() => orderFilter = label),
                  selectedColor: _accountPurple.withValues(alpha: .16),
                  labelStyle: TextStyle(color: orderFilter == label ? _accountPurple : null, fontWeight: orderFilter == label ? FontWeight.w700 : FontWeight.normal),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: filtered.isEmpty
          ? Center(child: Text(allItems.isEmpty ? 'No orders found yet.' : 'No matching orders found.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                final lines = _asItems(item['items'] ?? item['line_items']);
                final first = lines.isEmpty ? <String, dynamic>{} : lines.first;
                final imageValue = first['image'] is Map ? (first['image'] as Map)['src'] : (first['image'] ?? first['image_url']);
                final image = (imageValue ?? '').toString();
                final title = (first['name'] ?? first['product_name'] ?? (lines.isEmpty ? 'Order details' : 'Product')).toString();
                final qty = lines.fold<int>(0, (sum, line) => sum + (int.tryParse((line['quantity'] ?? 1).toString()) ?? 1));
                final id = (item['id'] ?? item['order_id'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: id.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(token: widget.token, order: item))),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(children: [
                        Row(children: [
                          const Icon(Icons.receipt_long, color: _accountPurple),
                          const SizedBox(width: 9),
                          Expanded(child: Text('Order #${item['number'] ?? id}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                          Text(_orderTotal(item), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right),
                        ]),
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerLeft, child: Builder(builder: (context) {
                          final state = _normalStatus(item['status_key'] ?? item['status']);
                          final color = state == 'delivered' ? Colors.green : ['cancelled','failed','refunded'].contains(state) ? Colors.red : ['hold','payment-pending'].contains(state) ? Colors.deepOrange : state == 'out-for-delivery' ? Colors.teal : state == 'shipped' ? Colors.indigo : _accountPurple;
                          final label = state.replaceAll('-', ' ').toUpperCase();
                          return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(30)), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)));
                        })),
                        const SizedBox(height: 14),
                        Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: SizedBox(
                              width: 82, height: 82,
                              child: image.isEmpty
                                ? const ColoredBox(color: Color(0xFFF1EDF7), child: Icon(Icons.shopping_bag_outlined, color: _accountPurple, size: 34))
                                : Image.network(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF1EDF7), child: Icon(Icons.image_not_supported_outlined, color: _accountPurple))),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_shortTitle(title), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 7),
                            Text('Quantity × $qty', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ])),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
      ),
    ]);
  }
}

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.token, required this.order});
  final String token;
  final Map<String, dynamic> order;
  @override State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> order;
  bool loading = false;
  String? error;
  Timer? _statusTimer;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
    refresh();
    // Keep the order status and its colour/timeline in sync with WooCommerce.
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted && !loading) refresh(); });
  }
  @override void dispose() { _statusTimer?.cancel(); pulse.dispose(); super.dispose(); }

  String get status => (order['status_key'] ?? order['status'] ?? 'pending').toString().toLowerCase().replaceAll('_', '-').replaceFirst(RegExp(r'^wc-'), '');
  String get normalizedStatus {
    if (status == 'on-hold' || status == 'hold') return 'hold';
    if (['pending','pending-payment','payment-pending','awaiting-payment','awaiting-verification'].contains(status)) return 'payment-pending';
    if (['outfordelivery','out-of-delivery','out-for-delivery','out-for-delivery-status'].contains(status)) return 'out-for-delivery';
    if (['completed','complete','delivered'].contains(status)) return 'delivered';
    if (status == 'canceled') return 'cancelled';
    return status;
  }

  int get activeStep {
    switch (normalizedStatus) {
      case 'confirmed': return 1;
      case 'processing': return 2;
      case 'shipped': return 3;
      case 'out-for-delivery': return 4;
      case 'delivered': return 5;
      case 'hold':
      case 'payment-pending': return 0;
      default: return -1;
    }
  }

  Color get statusColor {
    switch (normalizedStatus) {
      case 'delivered': return Colors.green;
      case 'cancelled': case 'failed': case 'refunded': return Colors.red;
      case 'hold': case 'payment-pending': return Colors.deepOrange;
      case 'draft': return Colors.blueGrey;
      case 'out-for-delivery': return Colors.teal;
      case 'shipped': return Colors.indigo;
      case 'processing': case 'confirmed': return _accountPurple;
      default: return Colors.blueGrey;
    }
  }

  String get statusLabel => switch (normalizedStatus) {
    'hold' => 'ON HOLD',
    'payment-pending' => 'PAYMENT PENDING',
    'out-for-delivery' => 'OUT FOR DELIVERY',
    'delivered' => 'DELIVERED',
    'cancelled' => 'CANCELLED',
    'failed' => 'FAILED',
    'refunded' => 'REFUNDED',
    'draft' => 'DRAFT',
    'confirmed' => 'CONFIRMED',
    _ => normalizedStatus.replaceAll('-', ' ').toUpperCase(),
  };

  String _dateTime(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return '';
    final d = parsed.toLocal();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} • $hour:$minute $suffix';
  }

  String _stepDate(String key, int index) {
    final history = order['timeline'];
    if (history is List) {
      for (final raw in history.whereType<Map>()) {
        final eventKey = (raw['key'] ?? '').toString().toLowerCase().replaceAll('_', '-');
        final mapped = eventKey == 'completed' ? 'delivered' : eventKey == 'out-of-delivery' ? 'out-for-delivery' : eventKey;
        if (mapped == key) {
          final date = _dateTime(raw['date'] ?? raw['date_created'] ?? raw['timestamp'] ?? raw['time']);
          if (date.isNotEmpty) return date;
        }
      }
    }
    if (key == 'placed') return _dateTime(order['date_created'] ?? order['date']);
    if (index == activeStep) return _dateTime(order['date_modified'] ?? order['date_updated']);
    return '';
  }

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

  Future<void> changeDeliveryAddress() async {
    final id = (order['id'] ?? order['order_id'] ?? '').toString();
    if (id.isEmpty) return;
    final current = order['shipping'] is Map
        ? Map<String, dynamic>.from(order['shipping'] as Map)
        : <String, dynamic>{};
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderShippingAddressPage(
          token: widget.token,
          orderId: id,
          initialAddress: current,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => order = updated);
    await refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery address updated. Store may review shipping charges.')),
      );
    }
  }

  Future<void> cancel() async {
    final id = (order['id'] ?? order['order_id'] ?? '').toString();
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('This cancellation request will be sent to the store.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP ORDER')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CANCEL ORDER')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await ArkCustomerApi(widget.token).request('customer/orders/$id/cancel', method: 'POST', body: {'reason': 'Cancelled by customer'});
      final normalized = result is Map && result['order'] is Map ? result['order'] : result;
      if (normalized is Map) order = Map<String, dynamic>.from(normalized);
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancellation request sent.')));
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => loading = false); }
  }

  String money(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    final amount = double.tryParse(value.toString().replaceAll(',', ''));
    if (amount == null) return value.toString();
    return '${order['currency_symbol'] ?? '₹'}${amount.toStringAsFixed(2)}';
  }

  Widget detailRow(String label, dynamic value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      const SizedBox(width: 12),
      Flexible(child: Text(value == null || value.toString().isEmpty ? '—' : value.toString(), textAlign: TextAlign.end, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
    ]),
  );

  Widget timeline() {
    const steps = [
      ('placed', 'Order placed'),
      ('confirmed', 'Confirmed'),
      ('processing', 'Processing'),
      ('shipped', 'Shipped'),
      ('out-for-delivery', 'Out for delivery'),
      ('delivered', 'Delivered'),
    ];
    final terminal = ['cancelled','failed','refunded','draft'].contains(normalizedStatus);
    final current = activeStep;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('ORDER STATUS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .5))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: statusColor.withValues(alpha: .13), borderRadius: BorderRadius.circular(30)), child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12))),
          ]),
          if (['hold','payment-pending','draft'].contains(normalizedStatus)) ...[
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withValues(alpha: .22))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(normalizedStatus == 'hold' ? Icons.pause_circle_outline : normalizedStatus == 'draft' ? Icons.edit_note : Icons.payments_outlined, color: statusColor), const SizedBox(width: 9), Expanded(child: Text(normalizedStatus == 'hold' ? 'Your order is on hold while the store reviews it.' : normalizedStatus == 'draft' ? 'This order is still a draft and has not entered fulfilment.' : 'Payment is pending. The order will move forward after the store verifies payment.', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)))])),
          ],
          if (terminal) ...[
            const SizedBox(height: 14),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(normalizedStatus == 'cancelled' ? Icons.cancel_outlined : Icons.info_outline, color: statusColor), const SizedBox(width: 8), Expanded(child: Text(normalizedStatus == 'draft' ? 'Draft order — fulfilment has not started.' : statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)))])),
          ],
          const SizedBox(height: 17),
          for (var i = 0; i < steps.length; i++) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 30, child: Column(children: [
                AnimatedBuilder(
                  animation: pulse,
                  builder: (_, __) {
                    final done = !terminal && current >= i;
                    final active = !terminal && current == i;
                    final stepColor = active ? statusColor : _accountPurple;
                    return Container(
                      width: active ? 27 : 23, height: active ? 27 : 23,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: done ? stepColor : Theme.of(context).colorScheme.surfaceContainerHighest, border: Border.all(color: active ? statusColor : Colors.transparent, width: 2), boxShadow: active ? [BoxShadow(color: statusColor.withValues(alpha: .18 + pulse.value * .24), blurRadius: 5 + pulse.value * 5)] : []),
                      child: Icon(done ? Icons.check : Icons.circle, size: done ? 14 : 7, color: done ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                    );
                  },
                ),
                if (i != steps.length - 1) Container(width: 2, height: 34, color: !terminal && current > i ? _accountPurple : Theme.of(context).colorScheme.outlineVariant),
              ])),
              const SizedBox(width: 9),
              Expanded(child: Padding(padding: const EdgeInsets.only(top: 2, bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(steps[i].$2, style: TextStyle(fontWeight: !terminal && current == i ? FontWeight.w800 : FontWeight.w600, color: !terminal && current >= i ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
                if (_stepDate(steps[i].$1, i).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(_stepDate(steps[i].$1, i), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)))
                else if (!terminal && current >= i) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Time not provided by store', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))),
              ]))),
            ]),
          ],
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final lineItems = (order['items'] as List? ?? order['line_items'] as List? ?? const []).whereType<Map>().toList();
    final shipping = order['shipping'] is Map ? order['shipping'] as Map : const {};
    final canCancel = order['can_cancel'] == true || (order['can_cancel'] == null && ['payment-pending','hold','processing','confirmed'].contains(normalizedStatus));
    final canChangeAddress = order['can_change_address'] == true ||
        (order['can_change_address'] == null && ['payment-pending', 'hold'].contains(normalizedStatus));
    final subtotal = order['subtotal'] ?? order['cart_subtotal'] ?? order['line_items_subtotal'];
    final shippingTotal = order['shipping_total'] ?? order['shipping_cost'] ?? order['shipping_amount'];
    final tax = order['total_tax'] ?? order['tax_total'] ?? order['tax'];
    final total = order['total'] ?? order['total_amount'] ?? order['order_total'];
    return Scaffold(
      appBar: AppBar(title: Text('Order #${order['number'] ?? order['id'] ?? ''}'), actions: [IconButton(onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 24), children: [
        timeline(),
        const SizedBox(height: 10),
        const Padding(padding: EdgeInsets.only(left: 3, bottom: 4), child: Text('ITEMS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        ...lineItems.map((item) {
          final image = item['image'] is Map ? (item['image'] as Map)['src']?.toString() ?? '' : (item['image'] ?? item['image_url'] ?? '').toString();
          final rawTitle = (item['name'] ?? item['product_name'] ?? 'Product').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
          final title = rawTitle.length > 48 ? '${rawTitle.substring(0, 45).trimRight()}…' : rawTitle;
          return Card(child: Padding(padding: const EdgeInsets.all(11), child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 76, height: 76, child: image.isEmpty ? const Icon(Icons.shopping_bag_outlined, size: 35) : Image.network(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Qty: ${item['quantity'] ?? 1}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            const SizedBox(width: 8),
            Text(money(item['total'] ?? item['line_total'] ?? item['subtotal']), style: const TextStyle(fontWeight: FontWeight.w700)),
          ])));
        }),
        Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [
          detailRow('Subtotal', money(subtotal)),
          detailRow('Shipping', money(shippingTotal)),
          detailRow('Tax', money(tax)),
          if (order['discount_total'] != null) detailRow('Discount', '-${money(order['discount_total'])}'),
          const Divider(height: 18),
          detailRow('Total amount', money(total), bold: true),
          detailRow('Payment method', order['payment_method_title'] ?? order['payment_method']),
          detailRow('Payment status', (order['payment_status'] ?? (normalizedStatus == 'completed' || normalizedStatus == 'delivered' ? 'Paid' : statusLabel)).toString().toUpperCase()),
        ]))),
        Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('DELIVERY ADDRESS', style: TextStyle(fontWeight: FontWeight.w800))),
            if (canChangeAddress)
              TextButton.icon(
                onPressed: loading ? null : changeDeliveryAddress,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('CHANGE'),
              ),
          ]),
          const SizedBox(height: 8),
          Text([shipping['first_name'], shipping['last_name'], shipping['company'], shipping['address_1'], shipping['address_2'], shipping['city'], shipping['state'], shipping['postcode'], shipping['country']].where((v) => v != null && v.toString().isNotEmpty).join(', ').isEmpty ? 'Address not available' : [shipping['first_name'], shipping['last_name'], shipping['company'], shipping['address_1'], shipping['address_2'], shipping['city'], shipping['state'], shipping['postcode'], shipping['country']].where((v) => v != null && v.toString().isNotEmpty).join(', ')),
          if (!canChangeAddress)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Address changes are locked after the order leaves the pending / on-hold stage.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ]))),
        if (error != null) Padding(padding: const EdgeInsets.all(8), child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (canCancel) Padding(padding: const EdgeInsets.only(top: 6), child: OutlinedButton.icon(onPressed: loading ? null : cancel, icon: const Icon(Icons.cancel_outlined), label: const Text('CANCEL ORDER'))),
        if (loading) const Padding(padding: EdgeInsets.all(10), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}


class OrderShippingAddressPage extends StatefulWidget {
  const OrderShippingAddressPage({
    super.key,
    required this.token,
    required this.orderId,
    required this.initialAddress,
  });
  final String token;
  final String orderId;
  final Map<String, dynamic> initialAddress;

  @override
  State<OrderShippingAddressPage> createState() => _OrderShippingAddressPageState();
}

class _OrderShippingAddressPageState extends State<OrderShippingAddressPage> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    const keys = [
      'first_name', 'last_name', 'phone', 'address_1', 'address_2',
      'city', 'state', 'postcode', 'country',
    ];
    fields = {
      for (final key in keys)
        key: TextEditingController(
          text: (widget.initialAddress[key] ?? (key == 'country' ? 'IN' : '')).toString(),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get address =>
      fields.map((key, controller) => MapEntry(key, controller.text.trim()))
        ..['country'] = (fields['country']!.text.trim().isEmpty ? 'IN' : fields['country']!.text.trim()).toUpperCase();

  Widget field(String key, String label, {bool required = true, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: fields[key],
        keyboardType: type,
        textCapitalization: key == 'country' ? TextCapitalization.characters : TextCapitalization.words,
        decoration: material.InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) return 'Enter $label';
          if (key == 'postcode' && value != null && value.trim().length < 5) return 'Enter a valid PIN code';
          return null;
        },
      ),
    );
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() { saving = true; error = null; });
    try {
      final response = await ArkCustomerApi(widget.token).request(
        'customer/orders/${widget.orderId}/address',
        method: 'PUT',
        body: address,
      );
      final updated = response is Map && response['order'] is Map
          ? response['order']
          : response;
      if (updated is! Map || updated['id'] == null) {
        throw Exception('The store did not return the updated order details.');
      }
      if (mounted) Navigator.pop(context, Map<String, dynamic>.from(updated));
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change delivery address')),
    body: Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDFA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(children: [
              Icon(Icons.local_shipping_outlined, color: _accountPurple, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text('Update the delivery address for this order. Available only before fulfilment begins.', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: field('first_name', 'First name')),
            const SizedBox(width: 10),
            Expanded(child: field('last_name', 'Last name')),
          ]),
          field('phone', 'Mobile number', type: TextInputType.phone),
          field('address_1', 'House / street / area'),
          field('address_2', 'Landmark (optional)', required: false),
          Row(children: [
            Expanded(child: field('city', 'City')),
            const SizedBox(width: 10),
            Expanded(child: field('state', 'State')),
          ]),
          Row(children: [
            Expanded(child: field('postcode', 'PIN code', type: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: field('country', 'Country code')),
          ]),
          if (error != null)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline),
              label: Text(saving ? 'UPDATING…' : 'UPDATE DELIVERY ADDRESS'),
              style: FilledButton.styleFrom(backgroundColor: _accountPurple),
            ),
          ),
        ],
      ),
    ),
  );
}


/// Dedicated add/edit screen for WooCommerce-backed saved delivery addresses.
class SavedAddressFormPage extends StatefulWidget {
  const SavedAddressFormPage({super.key, required this.token, this.initialAddress});
  final String token;
  final Map<String, dynamic>? initialAddress;
  @override State<SavedAddressFormPage> createState() => _SavedAddressFormPageState();
}

class _SavedAddressFormPageState extends State<SavedAddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final ArkCustomerApi _api;
  late final Map<String, TextEditingController> _fields;
  String _label = 'Home';
  bool _saving = false;
  String? _error;

  static const _definitions = <(String, String, IconData)>[
    ('first_name', 'First name', Icons.person_outline),
    ('last_name', 'Last name', Icons.person_outline),
    ('phone', 'Mobile number', Icons.phone_outlined),
    ('email', 'Email address', Icons.email_outlined),
    ('address_1', 'House / street / area', Icons.home_outlined),
    ('address_2', 'Landmark (optional)', Icons.near_me_outlined),
    ('city', 'City', Icons.location_city_outlined),
    ('state', 'State', Icons.map_outlined),
    ('postcode', 'PIN code', Icons.markunread_mailbox_outlined),
    ('country', 'Country code', Icons.flag_outlined),
  ];

  @override void initState() {
    super.initState();
    _api = ArkCustomerApi(widget.token);
    final initial = widget.initialAddress ?? const <String, dynamic>{};
    _label = (initial['label'] ?? 'Home').toString();
    _fields = {
      for (final entry in _definitions)
        entry.$1: TextEditingController(text: (initial[entry.$1] ?? (entry.$1 == 'country' ? 'IN' : '')).toString()),
    };
  }

  @override void dispose() {
    for (final controller in _fields.values) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final payload = <String, dynamic>{
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
        'label': _label,
      };
      final id = widget.initialAddress?['id'];
      if (id != null && id.toString().isNotEmpty) payload['id'] = id;
      await _api.request('customer/addresses', method: 'POST', body: payload);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _input((String, String, IconData) definition) {
    final key = definition.$1;
    final optional = key == 'address_2';
    final keyboard = key == 'email' ? TextInputType.emailAddress :
      key == 'phone' || key == 'postcode' ? TextInputType.phone : TextInputType.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: _fields[key],
        keyboardType: keyboard,
        textCapitalization: key == 'email' ? TextCapitalization.none : TextCapitalization.words,
        validator: optional ? null : (value) {
          final text = (value ?? '').trim();
          if (text.isEmpty) return 'Required';
          if (key == 'postcode' && text.length < 5) return 'Enter a valid PIN code';
          if (key == 'phone' && text.replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter a valid mobile number';
          if (key == 'email' && !RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$').hasMatch(text)) return 'Enter a valid email address';
          return null;
        },
        decoration: material.InputDecoration(
          labelText: definition.$2,
          prefixIcon: Icon(definition.$3, color: _accountPurple),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .32),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          errorMaxLines: 2,
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final editing = widget.initialAddress != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Address' : 'New Address'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF33205F), Color(0xFF7655A8)]),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(editing ? 'UPDATE DELIVERY PLACE' : 'ADD DELIVERY PLACE', style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(editing ? 'Keep your address up to date.' : 'Where should we deliver?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                ])),
              ]),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _label,
              decoration: material.InputDecoration(
                labelText: 'Address type',
                prefixIcon: const Icon(Icons.bookmark_outline, color: _accountPurple),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .32),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'Home', child: Text('Home')),
                DropdownMenuItem(value: 'Work', child: Text('Work')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
                DropdownMenuItem(value: 'Default', child: Text('Default')),
              ],
              onChanged: _saving ? null : (value) => setState(() => _label = value ?? 'Home'),
            ),
            const SizedBox(height: 14),
            for (final definition in _definitions) _input(definition),
            if (_error != null) Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_done_rounded),
                label: Text(_saving ? 'SAVING TO YOUR ACCOUNT…' : editing ? 'UPDATE ADDRESS' : 'SAVE ADDRESS'),
                style: FilledButton.styleFrom(backgroundColor: _accountPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}