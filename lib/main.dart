import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'designer_banner_carousel.dart';
import 'product_details_page.dart';
import 'customer_account_page.dart';
import 'checkout_page.dart';
import 'woo_store_api.dart';
import 'notification_service.dart';
import 'notification_inbox_page.dart';
import 'glowhit_designer_page.dart';

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
            child: AccountPanel(token: null, onLogin: onLogin, onLogout: () {}, onRecentViewed: () {}),
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
  List<Map<String, dynamic>> storeCategories = [];
  Map<String, dynamic> designerConfig = {};
  final Map<String, Future<Map<String, dynamic>>> _sliderFutures = {};
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
    _loadDesignerConfig();
    _loadStoreCategories();
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
  Future<void> _rememberRecentlyViewed(Map<String, dynamic> product) async {
    final id = (product['id'] ?? '').toString();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('glowhit_recent_viewed') ?? [];
    final saved = <Map<String, dynamic>>[];
    for (final entry in raw) {
      try {
        final value = jsonDecode(entry);
        if (value is Map && (value['id'] ?? '').toString() != id) saved.add(Map<String, dynamic>.from(value));
      } catch (_) {}
    }
    final images = product['images'] is List ? (product['images'] as List).take(3).toList() : [];
    final compact = <String, dynamic>{
      'id': product['id'], 'name': product['name'], 'permalink': product['permalink'],
      'images': images, 'prices': product['prices'], 'short_description': product['short_description'],
      'description': product['description'], 'average_rating': product['average_rating'],
      'stock_status': product['stock_status'],
    };
    saved.insert(0, compact);
    await prefs.setStringList('glowhit_recent_viewed', saved.take(12).map(jsonEncode).toList());
  }

  Future<void> _openRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = <Map<String, dynamic>>[];
    for (final entry in prefs.getStringList('glowhit_recent_viewed') ?? []) {
      try {
        final value = jsonDecode(entry);
        if (value is Map && value['id'] != null && (value['name'] ?? '').toString().trim().isNotEmpty) {
          rows.add(Map<String, dynamic>.from(value));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RecentlyViewedPage(
      products: rows,
      onOpen: (product) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(
          product: product,
          onAddToCart: () => _addToCart(product),
          onBuyNow: () => _buyNow(product),
          isWishlisted: wishlist.any((e) => e['id'] == product['id']),
          onWishlist: () => setState(() {
            wishlist.any((e) => e['id'] == product['id'])
              ? wishlist.removeWhere((e) => e['id'] == product['id'])
              : wishlist.add(product);
          }),
        )));
      },
    )));
  }

  Widget productCard(Map<String, dynamic> p) {
    final id = (p['id'] as num?)?.toInt() ?? 0;
    final liked = wishlist.any((e) => e['id'] == id);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0.5,
      child: InkWell(
        onTap: () {
          _rememberRecentlyViewed(p);
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(
            product: p,
            onAddToCart: () => _addToCart(p),
            onBuyNow: () => _buyNow(p),
            isWishlisted: liked,
            onWishlist: () => setState(() {
              liked ? wishlist.removeWhere((e) => e['id'] == id) : wishlist.add(p);
            }),
          )));
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            Container(
              color: Colors.white,
              child: imageUrl(p).isEmpty
                ? const Icon(Icons.image_outlined, size: 44, color: Colors.black26)
                : Image.network(imageUrl(p), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
            ),
            Positioned(right: 4, top: 4, child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton.filledTonal(onPressed: () => setState(() {
                liked ? wishlist.removeWhere((e) => e['id'] == id) : wishlist.add(p);
              }), icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : null)),
              IconButton.filledTonal(onPressed: () => Share.share('${p['name']}\\n${p['permalink'] ?? storeUrl}'), icon: const Icon(Icons.share_outlined)),
            ])),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(9, 7, 9, 2), child: Text((p['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 9), child: Text(price(p), style: const TextStyle(fontWeight: FontWeight.w800, color: purple))),
          Padding(padding: const EdgeInsets.fromLTRB(7, 2, 7, 7), child: SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: () => _addToCart(p), child: const Text('ADD TO CART', style: TextStyle(fontSize: 10))))),
        ]),
      ),
    );
  }
  Future<void> _openDesigner() async {
    final token = customerToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to open ARK Designer.')));
      setState(() => tab = 4);
      return;
    }
    try {
      await ArkCustomerApi(token).request('designer/config');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ARK Designer requires a WordPress administrator account. $e'),
        ));
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GlowHitDesignerPage(token: token)));
    await _loadDesignerConfig();
  }

  Future<void> _loadDesignerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('glowhit_published_designer_config');
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map && mounted) setState(() => designerConfig = Map<String, dynamic>.from(decoded));
      } catch (_) {}
    }
    try {
      final response = await http.get(
        Uri.parse('$storeUrl/wp-json/ark-designer/v1/config'),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['pages'] is Map) {
        final value = Map<String, dynamic>.from(decoded);
        await prefs.setString('glowhit_published_designer_config', jsonEncode(value));
        _sliderFutures.clear();
        if (mounted) setState(() => designerConfig = value);
      }
    } catch (_) {
      // The last published configuration remains available from local cache.
    }
  }

  Future<void> _loadStoreCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$storeUrl/wp-json/wc/store/v1/products/categories?per_page=40&hide_empty=true'),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is List && mounted) {
        setState(() => storeCategories = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _loadDesignerSlider(String key) async {
    final response = await http.get(
      Uri.parse('$storeUrl/wp-json/ark-designer/v1/sliders/$key'),
      headers: const {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Slider unavailable');
    final value = jsonDecode(response.body);
    if (value is! Map) throw Exception('Invalid slider response');
    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _designerProducts(Map<String, dynamic> section) {
    final source = (section['source'] ?? 'latest').toString();
    final categoryId = (section['category_id'] as num?)?.toInt() ?? 0;
    var rows = products.where((p) {
      if (source == 'sale') return p['on_sale'] == true;
      if (source == 'featured') return p['is_featured'] == true;
      if (source == 'wishlist') return wishlist.any((w) => w['id'] == p['id']);
      if (source == 'category' && categoryId > 0) {
        final ids = p['categories'] is List ? (p['categories'] as List).whereType<Map>().map((c) => (c['id'] as num?)?.toInt()).toList() : <int?>[];
        return ids.contains(categoryId);
      }
      return true;
    }).toList();
    if (source == 'top_rated') {
      rows.sort((a, b) => ((b['average_rating'] as num?) ?? 0).compareTo((a['average_rating'] as num?) ?? 0));
    }
    final limit = (section['limit'] as num?)?.toInt() ?? 8;
    return rows.take(limit.clamp(1, 40)).toList();
  }

  Widget _designerSection(Map<String, dynamic> section) {
    if (section['visible'] == false) return const SizedBox.shrink();
    final type = (section['type'] ?? section['designer_component_type'] ?? '').toString();
    final title = (section['title'] ?? '').toString();
    final showTitle = section['show_title'] != false && title.isNotEmpty;
    final background = (section['section_background'] ?? 'transparent').toString();
    final textColor = (section['text_color'] ?? '#202733').toString();
    final padding = (section['padding_top'] as num?)?.toDouble() ?? 12.0;

    if (type == 'ark_live_slider' || type.startsWith('banner_') || section['designer_component_type']?.toString().startsWith('banner_') == true) {
      final key = (section['slider_key'] ?? '').toString();
      final inlineChildren = section['slides'] is List
          ? (section['slides'] as List)
          : (section['children'] is List ? section['children'] as List : const <dynamic>[]);
      final normalizedInline = inlineChildren.whereType<Map>().map((slide) {
        final item = Map<String, dynamic>.from(slide);
        item['image_url'] = item['image_url'] ?? item['source_url'] ?? item['url'] ?? '';
        return item;
      }).where((slide) => (slide['image_url'] ?? '').toString().isNotEmpty).toList();

      Widget renderCarousel(List<Map<String, dynamic>> slides, Map<String, dynamic> settings) {
        final height = ((settings['height_px'] ?? section['height_px'] ?? section['height'] ?? 180) as num).toDouble();
        final intervalMs = ((settings['interval_ms'] ?? section['interval_ms'] ?? (((section['autoplay_seconds'] as num?)?.toDouble() ?? 4) * 1000)) as num).toInt();
        final layout = (section['designer_component_type'] ?? section['type'] ?? '').toString();
        final bannerStyle = layout == 'banner_grid' || layout == 'banner_list' || layout == 'banner_scroll';
        return Padding(
          padding: EdgeInsets.only(top: padding, bottom: (section['padding_bottom'] as num?)?.toDouble() ?? 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showTitle) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _safeColor(textColor))),
            ),
            bannerStyle
                ? SizedBox(
                    height: height,
                    child: ListView(
                      scrollDirection: section['horizontal'] == false || layout == 'banner_list' ? Axis.vertical : Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: slides.map((slide) {
                        final url = (slide['image_url'] ?? slide['source_url'] ?? '').toString();
                        return Padding(
                          padding: EdgeInsets.all(((section['item_gap'] as num?)?.toDouble() ?? 8) / 2),
                          child: SizedBox(
                            width: (section['width_pct'] as num?)?.toDouble() == null ? 260 : MediaQuery.of(context).size.width * ((section['width_pct'] as num).toDouble() / 100),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular((section['corner_radius'] as num?)?.toDouble() ?? 16),
                              child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : ArkDesignerBannerCarousel(
                    slides: slides,
                    height: height,
                    radius: (section['corner_radius'] as num?)?.toDouble() ?? 16,
                    autoplay: section['autoplay'] != false,
                    interval: Duration(milliseconds: intervalMs.clamp(1000, 30000)),
                    pauseOnInteraction: section['pause_on_interaction'] != false,
                    showDots: section['show_dots'] == true,
                    showArrows: section['show_arrows'] == true,
                    fade: section['transition'] == 'fade',
                    viewFraction: ((section['card_width'] ?? section['view_fraction'] ?? 1) as num).toDouble(),
                  ),
          ]),
        );
      }

      if (key.isNotEmpty) {
        final future = _sliderFutures.putIfAbsent(key, () => _loadDesignerSlider(key));
        return FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, snapshot) {
            final payload = snapshot.data ?? <String, dynamic>{};
            final slides = payload['slides'] is List
                ? (payload['slides'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                : <Map<String, dynamic>>[];
            final settings = payload['settings'] is Map ? Map<String, dynamic>.from(payload['settings'] as Map) : <String, dynamic>{};
            if (slides.isEmpty) return SizedBox(height: (section['height_px'] as num?)?.toDouble() ?? 180, child: const Center(child: CircularProgressIndicator()));
            return renderCarousel(slides, settings);
          },
        );
      }
      if (normalizedInline.isNotEmpty) {
        return renderCarousel(normalizedInline, section);
      }
      if ((section['image_url'] ?? '').toString().isNotEmpty) {
        return renderCarousel([
          {'image_url': section['image_url'], 'title': title},
        ], section);
      }
      return const SizedBox.shrink();
    }
    if (type == 'category_grid' || type.startsWith('category_')) {
      final layout = (section['category_layout'] ?? section['layout_variant'] ?? 'grid').toString();
      final limit = (section['limit'] as num?)?.toInt() ?? 8;
      final rows = storeCategories.take(limit.clamp(1, 40)).toList();
      if (rows.isEmpty) return const SizedBox.shrink();
      final cards = rows.map((category) {
        final image = category['image'] is Map ? (category['image'] as Map)['src']?.toString() ?? '' : '';
        return SizedBox(
          width: layout == 'list' || layout == 'list_tile' ? double.infinity : 112,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              if (image.isNotEmpty) SizedBox(height: 82, width: double.infinity, child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined)))
              else const SizedBox(height: 82, child: Center(child: Icon(Icons.category_outlined, size: 34))),
              Padding(padding: const EdgeInsets.all(7), child: Text((category['name'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
            ]),
          ),
        );
      }).toList();
      return Container(
        color: background == 'transparent' ? null : _safeColor(background),
        padding: EdgeInsets.fromLTRB(12, padding, 12, (section['padding_bottom'] as num?)?.toDouble() ?? 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showTitle) Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _safeColor(textColor)))),
          if (layout == 'list' || layout == 'list_tile') Column(children: rows.map((c) => ListTile(leading: const Icon(Icons.category_outlined), title: Text((c['name'] ?? '').toString()))).toList())
          else SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: cards.map((card) => SizedBox(width: 120, child: card)).toList())),
        ]),
      );
    }

    if (type == 'product_grid' || type == 'product_carousel' || type.startsWith('product_')) {
      final rows = _designerProducts(section);
      if (rows.isEmpty) return const SizedBox.shrink();
      final layout = (section['layout_variant'] ?? section['designer_component_type'] ?? type).toString();
      return Container(
        color: background == 'transparent' ? null : _safeColor(background),
        padding: EdgeInsets.fromLTRB(12, padding, 12, (section['padding_bottom'] as num?)?.toDouble() ?? 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showTitle) Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _safeColor(textColor)))),
          if (layout.contains('carousel') || layout.contains('slider'))
            SizedBox(height: 260, child: ListView(scrollDirection: Axis.horizontal, children: rows.map((p) => SizedBox(width: 174, child: productCard(p))).toList()))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ((section['columns'] as num?)?.toInt() ?? 2).clamp(1, 4),
                childAspectRatio: (section['card_aspect_ratio'] as num?)?.toDouble() ?? .66,
                crossAxisSpacing: (section['item_gap'] as num?)?.toDouble() ?? 8,
                mainAxisSpacing: (section['item_gap'] as num?)?.toDouble() ?? 8,
              ),
              itemBuilder: (_, index) => productCard(rows[index]),
            ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Color _safeColor(String value) {
    final raw = value.replaceFirst('#', '');
    final parsed = int.tryParse(raw, radix: 16);
    return Color(parsed == null ? 0xFF202733 : (raw.length == 6 ? 0xFF000000 | parsed : parsed));
  }

  Widget _designerCatalog() {
    final page = designerConfig['pages'] is Map ? (designerConfig['pages'] as Map)['home'] : null;
    final sections = page is Map && page['sections'] is List ? page['sections'] as List : const <dynamic>[];
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), child: TextField(controller: searchController, onSubmitted: (v) { search = v; load(); }, decoration: InputDecoration(hintText: 'Search products, brands and more', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: () { searchController.clear(); search = ''; load(); }, icon: const Icon(Icons.close)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
      Expanded(child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: sections.whereType<Map>().map((s) => _designerSection(Map<String, dynamic>.from(s))).toList(),
      )),
    ]);
  }

  Widget catalog() => designerConfig['pages'] is Map && ((designerConfig['pages'] as Map)['home'] is Map) && (((designerConfig['pages'] as Map)['home'] as Map)['sections'] is List)
      ? _designerCatalog()
      : Column(children: [
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
  Widget account() => AccountPanel(onLogin: (token) { setState(() => customerToken = token); push.register(customerJwt: token); }, onLogout: () async { final token = customerToken; if (token != null) { try { await ArkCustomerApi(token).request('customer/logout', method: 'POST'); } catch (_) {} } try { await push.unlinkAccount(); } catch (_) {} final prefs = await SharedPreferences.getInstance(); await prefs.remove('glowhit_customer_session'); if (mounted) setState(() { customerToken = null; notificationCount = 0; }); }, token: customerToken, onRecentViewed: _openRecentlyViewed);
  @override Widget build(BuildContext context) {
    final titles = ['Shopping', 'Categories', 'Wishlist', 'Cart', 'Account'];
    Widget page;
    if (tab == 0) page = catalog();
    else if (tab == 1) page = const Center(child: Text('Product categories are available from the store catalog.'));
    else if (tab == 2) page = wishlist.isEmpty ? const Center(child: Text('Your wishlist is empty')) : GridView.count(crossAxisCount: 2, childAspectRatio: .66, children: wishlist.map(productCard).toList());
    else if (tab == 3) page = _cartPage();
    else page = account();
    return Scaffold(appBar: AppBar(title: Text(titles[tab]), actions: [
      if (tab == 0) IconButton(tooltip: 'ARK Designer', onPressed: _openDesigner, icon: const Icon(Icons.design_services_rounded)),
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
  const AccountPanel({super.key, required this.onLogin, required this.onLogout, required this.token, required this.onRecentViewed});
  final ValueChanged<String> onLogin;
  final VoidCallback onLogout;
  final VoidCallback onRecentViewed;
  final String? token;
  @override State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> with SingleTickerProviderStateMixin {
  final user = TextEditingController();
  final pass = TextEditingController();
  bool busy = false, profileLoading = false;
  String? error;
  String displayName = 'Customer';
  String email = '';
  late final AnimationController _helloPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..repeat(reverse: true);

  @override void initState() { super.initState(); if (widget.token != null) loadProfile(); }
  @override void didUpdateWidget(covariant AccountPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token && widget.token != null) loadProfile();
    if (widget.token == null) { displayName = 'Customer'; email = ''; }
  }
  @override void dispose() { user.dispose(); pass.dispose(); _helloPulse.dispose(); super.dispose(); }

  Future<void> loadProfile() async {
    final token = widget.token;
    if (token == null) return;
    setState(() => profileLoading = true);
    try {
      final value = await ArkCustomerApi(token).request('customer/me');
      if (!mounted || widget.token != token) return;
      if (value is Map) {
        final first = (value['first_name'] ?? '').toString().trim();
        final last = (value['last_name'] ?? '').toString().trim();
        final full = [first, last].where((v) => v.isNotEmpty).join(' ');
        final candidate = (value['display_name'] ?? '').toString().trim();
        setState(() {
          displayName = candidate.isNotEmpty ? candidate : (full.isNotEmpty ? full : 'Customer');
          email = (value['email'] ?? '').toString();
          profileLoading = false;
        });
      } else if (mounted) setState(() => profileLoading = false);
    } catch (_) {
      if (mounted) setState(() => profileLoading = false);
    }
  }

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      final token = await StoreApi.login(user.text, pass.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('glowhit_customer_session', token);
      widget.onLogin(token);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _menuTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .4))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Container(width: 45, height: 45, decoration: BoxDecoration(color: purple.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: purple)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  @override Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
    children: [
      if (widget.token == null) ...[
        const Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        const Text('Sign in to see your orders and shopping activity.'),
        const SizedBox(height: 22),
        TextField(controller: user, decoration: const InputDecoration(labelText: 'Email or username', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder())),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : submit, child: busy ? const CircularProgressIndicator() : const Text('SIGN IN')),
      ] else ...[
        AnimatedBuilder(
          animation: _helloPulse,
          builder: (context, child) => Transform.scale(scale: 0.985 + (_helloPulse.value * .015), child: child),
          child: Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF302052), Color(0xFF7356A6), Color(0xFF9B72B7)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: purple.withValues(alpha: .20), blurRadius: 20, offset: const Offset(0, 9))],
            ),
            child: Row(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .17), shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                child: Center(child: Text(displayName.trim().isEmpty ? 'G' : displayName.trim().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Hii,', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                if (email.isNotEmpty) Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (profileLoading) const Padding(padding: EdgeInsets.only(top: 4), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
              ])),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: widget.token!, section: 'Edit Profile'))),
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .16)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        const Padding(padding: EdgeInsets.only(left: 3, bottom: 10), child: Text('MY ACCOUNT', style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: purple))),
        _menuTile(context, Icons.receipt_long_rounded, 'My Orders', 'Track, cancel and review your purchases', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: widget.token!, section: 'My Orders')))),
        _menuTile(context, Icons.download_for_offline_rounded, 'Downloads', 'Your available digital purchases', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: widget.token!, section: 'Downloads')))),
        _menuTile(context, Icons.location_on_rounded, 'Saved Addresses', 'Manage delivery addresses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: widget.token!, section: 'Saved Addresses')))),
        _menuTile(context, Icons.person_rounded, 'Edit Profile', 'Update your name and contact details', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: widget.token!, section: 'Edit Profile')))),
        _menuTile(context, Icons.history_rounded, 'Recently Viewed', 'Continue browsing products you opened', widget.onRecentViewed),
        const SizedBox(height: 5),
        OutlinedButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('LOG OUT'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 15)),
        ),
      ],
    ],
  );
}

class RecentlyViewedPage extends StatelessWidget {
  const RecentlyViewedPage({super.key, required this.products, required this.onOpen});
  final List<Map<String, dynamic>> products;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recently Viewed')),
    body: products.isEmpty
      ? const Center(child: Text('Products you view will appear here.'))
      : GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .68, crossAxisSpacing: 11, mainAxisSpacing: 11),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final item = products[index];
            final images = item['images'] is List ? item['images'] as List : const [];
            final image = images.isNotEmpty && images.first is Map ? (images.first['src'] ?? images.first['thumbnail'] ?? '').toString() : '';
            final prices = item['prices'] is Map ? item['prices'] as Map : const {};
            final raw = int.tryParse((prices['price'] ?? '').toString()) ?? 0;
            final digits = (prices['currency_minor_unit'] as num?)?.toInt() ?? 2;
            final amount = prices.isEmpty ? '' : '${prices['currency_symbol'] ?? '₹'}${(raw / (digits == 0 ? 1 : (digits == 1 ? 10 : 100))).toStringAsFixed(digits)}';
            return Card(clipBehavior: Clip.antiAlias, child: InkWell(
              onTap: () => onOpen(item),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SizedBox(width: double.infinity, child: image.isEmpty ? const Icon(Icons.shopping_bag_outlined, size: 42) : Image.network(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)))),
                Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 2), child: Text((item['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 10), child: Text(amount, style: const TextStyle(color: purple, fontWeight: FontWeight.w800))),
              ]),
            ));
          },
        ),
  );
}
