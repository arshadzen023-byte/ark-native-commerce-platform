import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const storeUrl = 'https://pluginstore.shop';
const purple = Color(0xFF51408F);

Future<http.Response> request(Uri uri, {String method = 'GET', Map<String, String>? headers, String? body}) async {
  const waits = [Duration(milliseconds: 350), Duration(milliseconds: 900), Duration(milliseconds: 1600)];
  SocketException? dnsError;
  for (var i = 0; i < waits.length; i++) {
    final client = http.Client();
    try {
      final req = http.Request(method, uri);
      req.headers.addAll(headers ?? const {'Accept': 'application/json'});
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = body;
      }
      final response = await client.send(req).timeout(const Duration(seconds: 20));
      return await http.Response.fromStream(response).timeout(const Duration(seconds: 20));
    } on SocketException catch (e) {
      final m = e.message.toLowerCase();
      final dns = m.contains('failed host lookup') || m.contains('no address associated') || m.contains('name or service not known');
      if (!dns) rethrow;
      dnsError = e;
      if (i < waits.length - 1) await Future<void>.delayed(waits[i]);
    } finally {
      client.close();
    }
  }
  var diagnosis = 'DNS lookup failed';
  try {
    final addresses = await InternetAddress.lookup(uri.host).timeout(const Duration(seconds: 4));
    if (addresses.isNotEmpty) diagnosis = 'DNS resolved to ${addresses.map((e) => e.address).join(', ')}';
  } on SocketException catch (e) {
    diagnosis = 'DNS still failing: ${e.message}';
  } on TimeoutException {
    diagnosis = 'DNS lookup timed out';
  }
  throw Exception('Cannot resolve ${uri.host}. ${diagnosis}. Check phone Private DNS / network DNS and hosting DNS. ${dnsError?.message ?? ''}');
}

class StoreApi {
  static Uri products({String order = 'date', String search = '', bool sale = false}) {
    final params = <String, String>{'page':'1','per_page':'40','orderby':order,'order':'desc','catalog_visibility':'visible'};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (sale) params['on_sale'] = 'true';
    return Uri.parse(storeUrl).resolve('wp-json/wc/store/v1/products').replace(queryParameters: params);
  }
  static Future<List<Map<String, dynamic>>> getProducts({String order = 'date', String search = '', bool sale = false}) async {
    final r = await request(products(order: order, search: search, sale: sale));
    if (r.statusCode != 200) throw Exception('WooCommerce HTTP ${r.statusCode}: ${r.body}');
    final value = jsonDecode(r.body);
    if (value is! List) throw Exception('Unexpected WooCommerce response');
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  static Future<String> login(String username, String password) async {
    final uri = Uri.parse(storeUrl).resolve('wp-json/ark-native/v1/auth/login');
    final r = await request(
      uri,
      method: 'POST',
      headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.trim(), 'password': password}),
    );

    dynamic data;
    try {
      data = jsonDecode(r.body);
    } on FormatException {
      throw Exception('The store returned an invalid response (HTTP ${r.statusCode}). Please check the WordPress REST API.');
    }

    if (r.statusCode < 200 || r.statusCode >= 300) {
      final message = data is Map
          ? (data['message'] ?? data['error'] ?? data['code'] ?? r.body).toString()
          : r.body;
      throw Exception('Login failed (HTTP ${r.statusCode}): $message');
    }

    if (data is! Map || data['success'] != true || (data['token'] ?? '').toString().isEmpty) {
      throw Exception('The store did not return a valid customer token.');
    }
    return data['token'].toString();
  }
}

void main() => runApp(const GlowHitApp());

class GlowHitApp extends StatelessWidget {
  const GlowHitApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GlowHit Shopping',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: purple), scaffoldBackgroundColor: const Color(0xFFF7F6FA)),
    home: const StoreHome(),
  );
}

class StoreHome extends StatefulWidget {
  const StoreHome({super.key});
  @override State<StoreHome> createState() => _StoreHomeState();
}

class _StoreHomeState extends State<StoreHome> {
  int tab = 0;
  bool loading = false;
  String? error;
  String search = '';
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> wishlist = [];
  final Map<int, Map<String, dynamic>> cart = {};
  final searchController = TextEditingController();
  String? customerToken;
  @override void initState() { super.initState(); load(); }
  @override void dispose() { searchController.dispose(); super.dispose(); }

  Future<void> load({String order = 'date', bool sale = false}) async {
    setState(() { loading = true; error = null; });
    try {
      final items = await StoreApi.getProducts(order: order, search: search, sale: sale);
      if (mounted) setState(() { products = items; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }
  int get cartCount => cart.values.fold(0, (n, p) => n + ((p['_qty'] as int?) ?? 1));
  String price(Map p) {
    final prices = p['prices'];
    if (prices is Map) {
      final raw = int.tryParse('${prices['price'] ?? ''}') ?? 0;
      final digits = (prices['currency_minor_unit'] as num?)?.toInt() ?? 2;
      return '${prices['currency_symbol'] ?? '₹'}${(raw / (digits == 0 ? 1 : (digits == 1 ? 10 : 100))).toStringAsFixed(digits)}';
    }
    return '';
  }
  String imageUrl(Map p) {
    final images = p['images'];
    if (images is List && images.isNotEmpty && images.first is Map) return (images.first['thumbnail'] ?? images.first['src'] ?? '').toString();
    return '';
  }
  Widget productCard(Map<String, dynamic> p) {
    final id = (p['id'] as num?)?.toInt() ?? 0;
    final liked = wishlist.any((e) => e['id'] == id);
    return Card(clipBehavior: Clip.antiAlias, elevation: 0.5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Stack(fit: StackFit.expand, children: [
        Container(color: Colors.white, child: imageUrl(p).isEmpty ? const Icon(Icons.image_outlined, size: 44, color: Colors.black26) : Image.network(imageUrl(p), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
        Positioned(right: 4, top: 4, child: IconButton.filledTonal(onPressed: () => setState(() { liked ? wishlist.removeWhere((e) => e['id'] == id) : wishlist.add(p); }), icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : null))),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(9, 7, 9, 2), child: Text((p['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 9), child: Text(price(p), style: const TextStyle(fontWeight: FontWeight.w800, color: purple))),
      Padding(padding: const EdgeInsets.fromLTRB(7, 2, 7, 7), child: SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: () => setState(() { cart[id] = {...p, '_qty': ((cart[id]?['_qty'] as int?) ?? 0) + 1}; }), child: const Text('ADD TO CART', style: TextStyle(fontSize: 10))))),
    ]));
  }
  Widget catalog() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), child: TextField(controller: searchController, onSubmitted: (v) { search = v; load(); }, decoration: InputDecoration(hintText: 'Search products, brands and more', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: () { searchController.clear(); search = ''; load(); }, icon: const Icon(Icons.close)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
    Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(18), width: double.infinity, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF33205F), Color(0xFF92517F)]), borderRadius: BorderRadius.circular(18)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('THE EVERYDAY EDIT', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 10)), SizedBox(height: 8), Text('Find your next\nfavourite thing.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)), SizedBox(height: 8), Text('SHOP THE COLLECTION  →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
    SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12), child: Row(children: [
      for (final item in [('For You','date',false),('Deals','date',true),('Top Rated','rating',false),('Featured','popularity',false)])
        Padding(padding: const EdgeInsets.only(right: 8), child: OutlinedButton(onPressed: () => load(order: item.$2, sale: item.$3), child: Text(item.$1))),
    ])),
    if (loading) const Expanded(child: Center(child: CircularProgressIndicator()))
    else if (error != null) Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 42, color: Colors.deepOrange), const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.deepOrange)), const SizedBox(height: 12), FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('Retry'))]))))
    else if (products.isEmpty) const Expanded(child: Center(child: Text('No products found. Try another search.')))
    else Expanded(child: GridView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 18), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .66, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: products.length, itemBuilder: (_, i) => productCard(products[i]))),
  ]);
  Widget account() => AccountPanel(onLogin: (token) => setState(() => customerToken = token), token: customerToken);
  @override Widget build(BuildContext context) {
    final titles = ['Shopping', 'Categories', 'Wishlist', 'Cart', 'Account'];
    Widget page;
    if (tab == 0) page = catalog();
    else if (tab == 1) page = const Center(child: Text('Product categories are available from the store catalog.'));
    else if (tab == 2) page = wishlist.isEmpty ? const Center(child: Text('Your wishlist is empty')) : GridView.count(crossAxisCount: 2, childAspectRatio: .66, children: wishlist.map(productCard).toList());
    else if (tab == 3) page = cart.isEmpty ? const Center(child: Text('Your cart is empty')) : ListView(children: cart.values.map((p) => ListTile(leading: SizedBox(width: 52, child: Image.network(imageUrl(p), errorBuilder: (_, __, ___) => const Icon(Icons.image))), title: Text(p['name'].toString()), subtitle: Text(price(p)), trailing: Text('×${p['_qty']}'))).toList());
    else page = account();
    return Scaffold(appBar: AppBar(title: Text(titles[tab]), actions: [if (tab == 0) IconButton(onPressed: load, icon: const Icon(Icons.refresh))]), body: SafeArea(child: page), bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: [
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.grid_view), label: 'Categories'),
      const NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Wishlist'),
      NavigationDestination(icon: Badge(label: Text('$cartCount'), child: const Icon(Icons.shopping_bag_outlined)), label: 'Cart'),
      const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
    ]));
  }
}

class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, required this.onLogin, required this.token});
  final ValueChanged<String> onLogin;
  final String? token;
  @override State<AccountPanel> createState() => _AccountPanelState();
}
class _AccountPanelState extends State<AccountPanel> {
  final user = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;
  @override void dispose() { user.dispose(); pass.dispose(); super.dispose(); }
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try { final token = await StoreApi.login(user.text, pass.text); widget.onLogin(token); }
    catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Welcome back', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text(widget.token == null ? 'Sign in to see your orders and shopping activity.' : 'You are signed in to your customer account.'),
    if (widget.token == null) ...[
      const SizedBox(height: 22),
      TextField(controller: user, decoration: const InputDecoration(labelText: 'Email or username', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 16),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN')),
    ] else const Padding(padding: EdgeInsets.only(top: 20), child: Icon(Icons.verified_user, size: 56, color: Colors.green)),
  ]);
}
