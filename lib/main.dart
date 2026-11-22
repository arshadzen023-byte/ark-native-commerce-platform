import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'product_details_page.dart';
import 'customer_account_page.dart';
import 'checkout_page.dart';
import 'woo_store_api.dart';
import 'notification_service.dart';
import 'notification_inbox_page.dart';

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
    final base = Uri.parse(storeUrl);
    var r = await request(base.resolve('wp-json/ark-native/v1/auth/login'), method: 'POST', body: jsonEncode({'username': username.trim(), 'email': username.trim(), 'password': password}));
    if (r.statusCode == 404 || r.statusCode == 405) {
      r = await request(base.resolve('wp-json/ark-native/v1/customer/login'), method: 'POST', body: jsonEncode({'email_or_username': username.trim(), 'username': username.trim(), 'password': password}));
    }
    dynamic data;
    try { data = jsonDecode(r.body); } catch (_) { throw Exception('Login returned an invalid server response (HTTP ${r.statusCode}).'); }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final message = data is Map ? (data['message'] ?? data['error'] ?? r.body) : r.body;
      throw Exception('Login failed (${r.statusCode}): $message');
    }
    if (data is! Map) {
      throw Exception('The store did not return a valid customer session.');
    }
    // The unified ARK Native Commerce Bridge /auth/login response returns
    // {success, token, user}; the compatibility /customer/login response
    // returns {success, session: {token}, customer}. Accept both contracts.
    final session = data['session'];
    final token = (data['token'] ?? (session is Map ? session['token'] : null) ?? '').toString();
    if (token.isEmpty) {
      throw Exception('The store did not return a valid customer token.');
    }
    return token;
  }
}

void main() => runApp(const GlowHitApp());

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool checking = true;
  String? token;
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('glowhit_customer_session');
    if (saved != null && saved.isNotEmpty) {
      try { await ArkCustomerApi(saved).request('customer/me'); token = saved; }
      catch (_) { await prefs.remove('glowhit_customer_session'); token = null; }
    }
    if (mounted) setState(() => checking = false);
  }
  @override Widget build(BuildContext context) {
    if (checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (token == null) return LoginLandingPage(onLogin: (value) => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => StoreHome(initialToken: value))));
    return StoreHome(initialToken: token);
  }
}

class LoginLandingPage extends StatelessWidget {
  const LoginLandingPage({super.key, required this.onLogin});
  final ValueChanged<String> onLogin;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('GlowHit Account')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(padding: const EdgeInsets.all(20), child: Card(
        child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.shopping_bag_rounded, size: 54, color: purple),
          const SizedBox(height: 14),
          const Text('Welcome to GlowHit', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Sign in to continue shopping', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          // AccountPanel contains a scrollable form; constrain it inside this
          // landing card so its ListView receives a finite height and paints.
          SizedBox(
            height: 340,
            child: AccountPanel(token: null, onLogin: onLogin, onLogout: () {}),
          ),
        ])),
      )),
    )),
  );
}


class GlowHitApp extends StatelessWidget {
  const GlowHitApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GlowHit Shopping',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: purple), scaffoldBackgroundColor: const Color(0xFFF7F6FA)),
    home: const SessionGate(),
  );
}

class StoreHome extends StatefulWidget {
  const StoreHome({super.key, this.initialToken});
  final String? initialToken;
  @override State<StoreHome> createState() => _StoreHomeState();
}

class _StoreHomeState extends State<StoreHome> {
  int tab = 0;
  bool loading = false;
  String? error;
  String search = '';
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> wishlist = [];
  final WooStoreApi woo = WooStoreApi();
  Map<String, dynamic> liveCart = {};
  bool cartBusy = false;
  final searchController = TextEditingController();
  String? customerToken;
  late final GlowHitPushService push;
  int notificationCount = 0;
  @override void initState() {
    super.initState();
    customerToken = widget.initialToken;
    push = GlowHitPushService(onTap: _handleNotificationLink, onForeground: _refreshNotificationCount);
    push.initialize(customerJwt: customerToken).then((_) => _refreshNotificationCount());
    load();
    _refreshCart();
  }
  Future<void> _refreshNotificationCount({bool markSeen = false}) async {
    try {
      final items = await push.loadInbox();
      final prefs = await SharedPreferences.getInstance();
      final latestId = items.fold<int>(0, (latest, item) {
        final id = int.tryParse((item['id'] ?? '').toString()) ?? 0;
        return id > latest ? id : latest;
      });
      const seenKey = 'glowhit_notifications_seen_through_id';
      final seenId = prefs.getInt(seenKey) ?? 0;
      if (markSeen && latestId > seenId) await prefs.setInt(seenKey, latestId);
      if (mounted) setState(() => notificationCount = markSeen ? 0 : items.where((item) {
        final id = int.tryParse((item['id'] ?? '').toString()) ?? 0;
        return id > seenId;
      }).length);
    } catch (_) {}
  }
  Future<void> _openNotifications() async {
    await _refreshNotificationCount(markSeen: true);
    final link = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => NotificationInboxPage(service: push)));
    await _refreshNotificationCount();
    if (link != null && link.isNotEmpty) await _handleNotificationLink(link);
  }
  Future<void> _handleNotificationLink(String? link) async {
    if (!mounted || link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (uri.scheme == 'ark' && uri.host == 'notifications') {
      await _openNotifications();
      return;
    }
    if (uri.scheme == 'ark' && (uri.host == 'orders' || uri.host == 'order')) {
      if (customerToken == null) { setState(() => tab = 4); return; }
      if (uri.pathSegments.isNotEmpty) {
        final id = uri.pathSegments.first;
        try {
          final data = await ArkCustomerApi(customerToken!).request('customer/orders/' + id);
          final order = data is Map && data['order'] is Map ? data['order'] : data;
          if (order is Map && mounted) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(token: customerToken!, order: Map<String, dynamic>.from(order))));
          }
        } catch (_) { if (mounted) setState(() => tab = 4); }
      } else {
        if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: customerToken!, section: 'My Orders')));
      }
      return;
    }
    if (uri.scheme == 'ark' && uri.host == 'product' && uri.pathSegments.isNotEmpty) {
      try {
        final response = await request(Uri.parse(storeUrl).resolve('wp-json/wc/store/v1/products/' + uri.pathSegments.first));
        if (response.statusCode == 200) {
          final product = jsonDecode(response.body);
          if (product is Map && mounted) {
            final p = Map<String, dynamic>.from(product);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p, onAddToCart: () => _addToCart(p), onBuyNow: () => _buyNow(p), isWishlisted: wishlist.any((e) => e['id'] == p['id']), onWishlist: () => setState(() { wishlist.any((e) => e['id'] == p['id']) ? wishlist.removeWhere((e) => e['id'] == p['id']) : wishlist.add(p); }))));
          }
        }
      } catch (_) {}
      return;
    }
    if (uri.scheme == 'ark' && uri.host == 'category') {
      if (mounted) setState(() => tab = 1);
      return;
    }
    if (uri.scheme == 'ark' && uri.host == 'page' && uri.pathSegments.isNotEmpty) {
      final pageId = int.tryParse(uri.pathSegments.first);
      if (pageId == null || pageId < 1) return;
      try {
        final response = await request(Uri.parse(storeUrl).resolve('wp-json/wp/v2/pages/$pageId?_fields=link,status'));
        if (response.statusCode == 200) {
          final page = jsonDecode(response.body);
          final link = page is Map && page['status'] == 'publish' ? (page['link'] ?? '').toString() : '';
          final target = Uri.tryParse(link);
          if (target != null && (target.scheme == 'https' || target.scheme == 'http')) {
            await launchUrl(target, mode: LaunchMode.externalApplication);
          }
        }
      } catch (_) {}
      return;
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    // Handle supported external app schemes selected in the WordPress composer.
    if (uri.scheme.isNotEmpty && uri.scheme != 'ark') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
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
  int get cartCount => (liveCart['items'] as List? ?? []).whereType<Map>().fold(0, (n, item) => n + ((item['quantity'] as num?)?.toInt() ?? 0));
  Future<void> _refreshCart() async {
    try { final value = await woo.getCart(); if (mounted) setState(() => liveCart = value); }
    catch (e) { if (mounted) setState(() => error = 'Cart: ' + e.toString().replaceFirst('Exception: ', '')); }
  }
  Future<bool> _addToCart(Map<String,dynamic> product) async {
    final id = (product['id'] as num?)?.toInt();
    if (id == null) return false;
    setState(() => cartBusy = true);
    try { final value = await woo.addItem(id); if (mounted) { setState(() => liveCart = value); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'))); } return true; }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); return false; }
    finally { if (mounted) setState(() => cartBusy = false); }
  }
  Future<void> _openCheckout() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => WooCheckoutPage(api: woo, customerToken: customerToken)));
    await _refreshCart();
  }
  Widget _cartPage() {
    final items = (liveCart['items'] as List? ?? []).whereType<Map>().toList();
    final totals = liveCart['totals'];
    String total = '';
    if (totals is Map) { final raw = int.tryParse('${totals['total_price'] ?? '0'}') ?? 0; final digits = (totals['currency_minor_unit'] as num?)?.toInt() ?? 2; total = '${totals['currency_symbol'] ?? '₹'}${(raw / (digits == 0 ? 1 : (digits == 1 ? 10 : 100))).toStringAsFixed(digits)}'; }
    if (cartBusy) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.shopping_bag_outlined, size: 54), const SizedBox(height: 12), const Text('Your cart is empty'), TextButton(onPressed: _refreshCart, child: const Text('Refresh cart'))]));
    return Column(children: [Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (_, i) { final item = items[i]; final imgs = item['images'] as List? ?? []; final src = imgs.isNotEmpty && imgs.first is Map ? (imgs.first['thumbnail'] ?? imgs.first['src'] ?? '').toString() : ''; final line = item['totals'] is Map ? item['totals'] as Map : const {}; final raw = int.tryParse('${line['line_total'] ?? '0'}') ?? 0; final digits = (line['currency_minor_unit'] as num?)?.toInt() ?? 2; final currency = (line['currency_symbol'] ?? '₹').toString(); final amount = '$currency${(raw / (digits == 0 ? 1 : (digits == 1 ? 10 : 100))).toStringAsFixed(digits)}'; return ListTile(leading: SizedBox(width: 56, child: src.isEmpty ? const Icon(Icons.image) : Image.network(src, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image))), title: Text((item['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('Qty: ${item['quantity'] ?? 1}  •  $amount'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { try { final updated = await woo.removeItem((item['key'] ?? '').toString()); if (mounted) setState(() => liveCart = updated); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } })); })), Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Cart total', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Text(total, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))]), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: _openCheckout, child: const Text('PROCEED TO CHECKOUT')))]))]);
  }
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
  Future<void> _buyNow(Map<String, dynamic> product) async {
    await _addToCart(product);
    if (mounted) await _openCheckout();
  }
  Widget productCard(Map<String, dynamic> p) {
    final id = (p['id'] as num?)?.toInt() ?? 0;
    final liked = wishlist.any((e) => e['id'] == id);
    return Card(clipBehavior: Clip.antiAlias, elevation: 0.5, child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p, onAddToCart: () => _addToCart(p), onBuyNow: () => _buyNow(p), isWishlisted: liked, onWishlist: () => setState(() { liked ? wishlist.removeWhere((e) => e['id'] == id) : wishlist.add(p); })))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Stack(fit: StackFit.expand, children: [
        Container(color: Colors.white, child: imageUrl(p).isEmpty ? const Icon(Icons.image_outlined, size: 44, color: Colors.black26) : Image.network(imageUrl(p), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
        Positioned(right: 4, top: 4, child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton.filledTonal(onPressed: () => setState(() { liked ? wishlist.removeWhere((e) => e['id'] == id) : wishlist.add(p); }), icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : null)), IconButton.filledTonal(onPressed: () => Share.share('${p['name']}\n${p['permalink'] ?? storeUrl}'), icon: const Icon(Icons.share_outlined))])),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(9, 7, 9, 2), child: Text((p['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 9), child: Text(price(p), style: const TextStyle(fontWeight: FontWeight.w800, color: purple))),
      Padding(padding: const EdgeInsets.fromLTRB(7, 2, 7, 7), child: SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: () => _addToCart(p), child: const Text('ADD TO CART', style: TextStyle(fontSize: 10))))),
    ])));
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
  Widget account() => AccountPanel(onLogin: (token) { setState(() => customerToken = token); push.register(customerJwt: token); }, onLogout: () async { final token = customerToken; if (token != null) { try { await ArkCustomerApi(token).request('customer/logout', method: 'POST'); } catch (_) {} } try { await push.unlinkAccount(); } catch (_) {} final prefs = await SharedPreferences.getInstance(); await prefs.remove('glowhit_customer_session'); if (mounted) setState(() { customerToken = null; notificationCount = 0; }); }, token: customerToken);
  @override Widget build(BuildContext context) {
    final titles = ['Shopping', 'Categories', 'Wishlist', 'Cart', 'Account'];
    Widget page;
    if (tab == 0) page = catalog();
    else if (tab == 1) page = const Center(child: Text('Product categories are available from the store catalog.'));
    else if (tab == 2) page = wishlist.isEmpty ? const Center(child: Text('Your wishlist is empty')) : GridView.count(crossAxisCount: 2, childAspectRatio: .66, children: wishlist.map(productCard).toList());
    else if (tab == 3) page = _cartPage();
    else page = account();
    return Scaffold(appBar: AppBar(title: Text(titles[tab]), actions: [
      if (tab == 0) IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      IconButton(
        tooltip: 'Notifications',
        onPressed: _openNotifications,
        icon: Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_none_rounded),
          if (notificationCount > 0) Positioned(right: -2, top: -2, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5))))),
        ]),
      ),
    ]), body: SafeArea(child: page), bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: [
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.grid_view), label: 'Categories'),
      const NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Wishlist'),
      NavigationDestination(icon: Badge(label: Text('$cartCount'), child: const Icon(Icons.shopping_bag_outlined)), label: 'Cart'),
      const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
    ]));
  }
}

class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, required this.onLogin, required this.onLogout, required this.token});
  final ValueChanged<String> onLogin;
  final VoidCallback onLogout;
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
    try { final token = await StoreApi.login(user.text, pass.text); final prefs = await SharedPreferences.getInstance(); await prefs.setString('glowhit_customer_session', token); widget.onLogin(token); }
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
    ] else ...[
      const Padding(padding: EdgeInsets.only(top: 20), child: Icon(Icons.verified_user, size: 56, color: Colors.green)),
      const SizedBox(height: 20),
      for (final item in [(Icons.receipt_long_outlined, 'My Orders'), (Icons.download_outlined, 'Downloads'), (Icons.location_on_outlined, 'Saved Addresses'), (Icons.person_outline, 'Edit Profile')])
        Card(child: ListTile(leading: Icon(item.$1, color: purple), title: Text(item.$2), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: widget.token!, section: item.$2))))),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: widget.onLogout, icon: const Icon(Icons.logout), label: const Text('LOG OUT')),
    ],
  ]);
}
