import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'designer_banner_carousel.dart';
import 'product_details_page.dart';
import 'customer_account_page.dart';
import 'checkout_page.dart';
import 'woo_store_api.dart';
import 'notification_service.dart';
import 'notification_inbox_page.dart';
import 'glowhit_designer_page.dart';
import 'designer_layout_contract.dart';
import 'designer_navigation_bar.dart';
import 'designer_app_bar.dart';
import 'search_page.dart';

const storeUrl = 'https://pluginstore.shop';
const purple = Color(0xFF51408F);

Alignment _designerBackgroundAlignment(dynamic value) {
  switch ((value ?? 'center').toString().toLowerCase()) {
    case 'top_left': return Alignment.topLeft;
    case 'top_center': return Alignment.topCenter;
    case 'top_right': return Alignment.topRight;
    case 'center_left': return Alignment.centerLeft;
    case 'center_right': return Alignment.centerRight;
    case 'bottom_left': return Alignment.bottomLeft;
    case 'bottom_center': return Alignment.bottomCenter;
    case 'bottom_right': return Alignment.bottomRight;
    default: return Alignment.center;
  }
}
BoxFit _designerBackgroundFit(dynamic value) {
  switch ((value ?? 'cover').toString().toLowerCase()) {
    case 'contain': return BoxFit.contain;
    case 'fill': return BoxFit.fill;
    case 'fit_width': return BoxFit.fitWidth;
    case 'fit_height': return BoxFit.fitHeight;
    default: return BoxFit.cover;
  }
}
TextStyle _designerFontStyle(String family, TextStyle base) {
  try {
    return GoogleFonts.getFont(family, textStyle: base);
  } catch (_) {
    return base.copyWith(fontFamily: family);
  }
}

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

/// Resolves legacy Banner layout metadata after WordPress normalizes
/// Banner Grid/List/Scroll/Slider sections to the shared ARK Live Slider type.
/// Older published JSON may contain only type=ark_live_slider + layout_variant.
String normalizeDesignerBannerLayoutType(Map<String, dynamic> config) {
  final rawType = (config['designer_component_type'] ?? config['type'] ?? '')
      .toString().toLowerCase();
  final variant = (config['layout_variant'] ?? '').toString().toLowerCase();
  if ((rawType == 'ark_live_slider' || rawType == 'banner_slider') &&
      const ['grid', 'list', 'scroll', 'slider'].contains(variant)) {
    return 'banner_$variant';
  }
  return rawType;
}

class StoreApi {
  static Uri products({String order = 'date', String search = '', bool sale = false, int page = 1}) {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': '40',
      'orderby': order,
      'order': 'desc',
      'catalog_visibility': 'visible',
      '_fields': 'id,name,slug,permalink,images,prices,on_sale,is_featured,average_rating,review_count,categories,tags,stock_status,date_created,total_sales',
    };
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
  int selectedNavigationIndex = 0;
  bool loading = false;
  String? error;
  String search = '';
  String deliveryAddressLabel = 'Deliver to your address';
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> wishlist = [];
  List<Map<String, dynamic>> storeCategories = [];
  Map<String, dynamic> designerConfig = {};
  bool designerConfigLoading = false;
  final Map<String, Future<Map<String, dynamic>>> _sliderFutures = {};
  final WooStoreApi woo = WooStoreApi();
  Map<String, dynamic> liveCart = {};
  bool cartBusy = false;
  final searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _voiceListening = false;
  String? customerToken;
  late final GlowHitPushService push;
  int notificationCount = 0;
  @override void initState() {
    super.initState();
    searchFocusNode.addListener(_handleSearchFocusChange);
    customerToken = widget.initialToken;
    push = GlowHitPushService(onTap: _handleNotificationLink, onForeground: _refreshNotificationCount);
    push.initialize(customerJwt: customerToken).then((_) => _refreshNotificationCount());
    load();
    _loadDesignerConfig();
    _loadStoreCategories();
    _refreshCart();
    _loadSelectedDeliveryAddress();
  }
  Future<void> _loadSelectedDeliveryAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('glowhit_selected_delivery_address');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final address = Map<String, dynamic>.from(decoded);
      final locality = [address['address_1'], address['address_2'], address['city'], address['postcode']]
          .where((v) => v != null && v.toString().trim().isNotEmpty)
          .map((v) => v.toString().trim()).join(', ');
      final label = (address['label'] ?? '').toString().trim();
      final full = locality.isNotEmpty ? locality : label;
      final compact = full.isEmpty ? 'Deliver to your address' : 'Deliver to $full';
      final display = compact.length > 20 ? '${compact.substring(0, 19)}…' : compact;
      if (mounted) setState(() => deliveryAddressLabel = display);
    } catch (_) {}
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
    final link = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => NotificationInboxPage(
      service: push,
      appBar: _buildConfiguredAppBar('notifications'),
      floatingActionButton: _buildDesignerFloatingAction('notifications'),
    )));
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
        if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: customerToken!, section: 'My Orders', appBar: _buildConfiguredAppBar('orders'))));
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
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p, onAddToCart: () => _addToCart(p), onBuyNow: () => _buyNow(p), isWishlisted: wishlist.any((e) => e['id'] == p['id']), onWishlist: () => setState(() { wishlist.any((e) => e['id'] == p['id']) ? wishlist.removeWhere((e) => e['id'] == p['id']) : wishlist.add(p); }), appBar: _buildConfiguredAppBar('product'), floatingActionButton: _buildDesignerFloatingAction('product'))));
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

  Future<void> _openDesignerChildLink(Map<String, dynamic> child) async {
    final linkType = (child['link_type'] ?? 'in_app').toString();
    final value = (child['link_value'] ?? child['link'] ?? '').toString().trim();
    if (value.isEmpty) return;
    if (linkType == 'chrome') {
      final uri = Uri.tryParse(value);
      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (value.startsWith('page:')) {
      final page = value.substring(5).toLowerCase();
      final nextTab = switch (page) {
        'home' => 0,
        'categories' => 1,
        'wishlist' => 2,
        'cart' => 3,
        'account' || 'orders' => 4,
        _ => -1,
      };
      if (nextTab >= 0 && mounted) setState(() => tab = nextTab);
      if (page == 'orders' && customerToken != null && mounted) {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => CustomerSectionPage(token: customerToken!, section: 'My Orders'),
        ));
      }
      return;
    }
    if (value.startsWith('product:')) {
      await _handleNotificationLink('ark://product/' + value.substring(8));
      return;
    }
    if (value.startsWith('category:')) {
      if (mounted) setState(() => tab = 1);
      return;
    }
    await _handleNotificationLink(value);
  }

  void _handleSearchFocusChange() { if (mounted) setState(() {}); }

  @override void dispose() { searchFocusNode.removeListener(_handleSearchFocusChange); _speech.stop(); searchController.dispose(); searchFocusNode.dispose(); super.dispose(); }

  Future<void> _startVoiceSearch() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) { if (mounted) setState(() => _voiceListening = status == 'listening'); },
        onError: (error) { if (mounted) { setState(() => _voiceListening = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice Search: ${error.errorMsg}'))); } },
      );
      if (!available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice Search is not available on this device.')));
        return;
      }
      final locales = await _speech.locales();
      String? selectedLocale;
      for (final preferred in const ['en_IN', 'hi_IN']) {
        for (final locale in locales) {
          if (locale.localeId.toLowerCase() == preferred.toLowerCase()) {
            selectedLocale = locale.localeId;
            break;
          }
        }
        if (selectedLocale != null) break;
      }
      if (mounted) setState(() => _voiceListening = true);
      await _speech.listen(
        localeId: selectedLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty || !mounted) return;
          setState(() { search = words; searchController.text = words; });
          if (result.finalResult) {
            setState(() => _voiceListening = false);
            load();
          }
        },
      );
    } catch (error) {
      if (mounted) {
        setState(() => _voiceListening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start Voice Search: $error')));
      }
    }
  }

  Future<void> _stopVoiceSearch() async {
    await _speech.stop();
    if (mounted) setState(() => _voiceListening = false);
  }

  bool _isNestedAppBarPage(String pageKey) => !const ['home','search','categories','wishlist','cart','account'].contains(pageKey);

  Future<void> _openAppBarMenu([String pageKey = 'home']) async {
    final choice = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final item in const [('home','Home',Icons.home_outlined),('categories','Categories',Icons.grid_view),('wishlist','Wishlist',Icons.favorite_border),('cart','Cart',Icons.shopping_cart_outlined),('account','Account',Icons.person_outline),('designer','ARK Designer',Icons.design_services_outlined)])
        ListTile(leading: Icon(item.$3), title: Text(item.$2), onTap: () => Navigator.pop(ctx, item.$1)),
    ])));
    if (!mounted || choice == null) return;
    if (choice == 'designer') { await _openDesigner(); return; }
    if (_isNestedAppBarPage(pageKey)) Navigator.of(context).pop();
    setState(() => tab = switch (choice) {'home' => 0, 'categories' => 1, 'wishlist' => 2, 'cart' => 3, _ => 4});
  }

  Future<void> _openAppBarCustomAction(Map<String, dynamic> action) async {
    final type = (action['link_type'] ?? 'page').toString();
    final target = (action['link_value'] ?? '').toString().trim();
    if (target.isEmpty) return;
    if (type == 'url') {
      final uri = Uri.tryParse(target);
      if (uri != null && const ['http','https'].contains(uri.scheme.toLowerCase()) && uri.host.isNotEmpty) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (type == 'deep_link') { await _handleNotificationLink(target); return; }
    if (type == 'page' && target.startsWith('custom_')) {
      final pages=designerConfig['pages'];
      final page=pages is Map ? pages[target] : null;
      if(page is Map) {
        final sections=page['sections'] is List ? (page['sections'] as List).whereType<Map>().where((e)=>e['visible']!=false).map((e)=>Map<String,dynamic>.from(e)).toList() : <Map<String,dynamic>>[];
        await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>Scaffold(appBar:_buildConfiguredAppBar(target),body:ListView(children:sections.map(_designerSection).toList()),floatingActionButton:_buildDesignerFloatingAction(target),bottomNavigationBar:_buildDesignerBottomNavigation())));
      }
      return;
    }
    switch (target.toLowerCase()) {
      case 'home': setState(() => tab = 0); break;
      case 'search': await _openSearchPage(); break;
      case 'categories': setState(() => tab = 1); break;
      case 'wishlist': setState(() => tab = 2); break;
      case 'cart': setState(() => tab = 3); break;
      case 'account': setState(() => tab = 4); break;
      case 'orders':
        if (customerToken != null) await Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: customerToken!, section: 'My Orders', appBar: _buildConfiguredAppBar('orders'))));
        else setState(() => tab = 4);
        break;
      case 'notifications': await _openNotifications(); break;
      case 'product':
        if(products.isNotEmpty) {
          final p=products.first;
          await Navigator.push(context,MaterialPageRoute(builder:(_)=>ProductDetailsPage(product:p,onAddToCart:()=>_addToCart(p),onBuyNow:()=>_buyNow(p),isWishlisted:wishlist.any((e)=>e['id']==p['id']),onWishlist:()=>setState((){wishlist.any((e)=>e['id']==p['id'])?wishlist.removeWhere((e)=>e['id']==p['id']):wishlist.add(p);}),appBar:_buildConfiguredAppBar('product'),floatingActionButton:_buildDesignerFloatingAction('product'))));
        }
        break;
      default:
        await _openNavigationItem(DesignerNavigationItem(id:'appbar-$target',label:(action['label']??'Action').toString(),link:'page',linkValue:'page:$target'),selectedNavigationIndex);
    }
  }

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
    await _loadSelectedDeliveryAddress();
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
          appBar: _buildConfiguredAppBar('product'),
            floatingActionButton: _buildDesignerFloatingAction('product'),
        )));
      },
    )));
  }

  Widget productCard(
    Map<String, dynamic> p, {
    double radius = 12,
    double elevation = 0.5,
  }) {
    final id = (p['id'] as num?)?.toInt() ?? 0;
    final liked = wishlist.any((e) => e['id'] == id);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: elevation.clamp(0, 12).toDouble(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.clamp(0, 60).toDouble())),
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
            appBar: _buildConfiguredAppBar('product'), floatingActionButton: _buildDesignerFloatingAction('product'),
          )));
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            Container(
              color: Colors.white,
              child: imageUrl(p).isEmpty
                ? const Icon(Icons.image_outlined, size: 44, color: Colors.black26)
                : Image.network(imageUrl(p), fit: BoxFit.contain,
                    cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio / 2).round().clamp(200, 1200),
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
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
      final response = await ArkCustomerApi(token).request('designer/config');
      if (response is Map && (response['pages'] is Map)) {
        // The bridge returns the existing ARK Designer WordPress config.
        // The editor reads this route itself; this call is a preflight only.
      }
    } catch (e) {
      final message = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message.contains('No route was found')
              ? 'ARK Designer API route is missing. Update and activate ARK App Designer + ARK Native API Bridge.'
              : 'ARK Designer access failed. Sign in with a WordPress administrator account. $e'),
        ));
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GlowHitDesignerPage(token: token)));
    // The Designer may have published while Shopping stayed alive. Always
    // re-fetch the public config when returning instead of relying on memory.
    await _loadDesignerConfig();
    if (mounted && tab == 0) setState(() {});
  }

  /// Loads the exact public Designer document used by Shopping Home.
  /// Never retain a stale cache when the server responds with a valid but empty
  /// published Home: empty is a real published state, not a reason to fall back.
  Future<void> _loadDesignerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('glowhit_published_designer_config');
    if (mounted) setState(() => designerConfigLoading = true);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          final value = Map<String, dynamic>.from(decoded);
          if (mounted) setState(() => designerConfig = value);
        }
      } catch (_) {}
    }

    try {
      final configUri = Uri.parse('$storeUrl/wp-json/ark-designer/v1/config')
          .replace(queryParameters: {
        '_glowhit_refresh': DateTime.now().microsecondsSinceEpoch.toString(),
      });
      final response = await http.get(
        configUri,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Published Designer config returned HTTP ${response.statusCode}.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['pages'] is! Map) {
        throw const FormatException('Published Designer config must contain a pages object.');
      }

      final value = Map<String, dynamic>.from(decoded);
      final rawPages = Map<String, dynamic>.from(value['pages'] as Map);
      final rawHome = rawPages['home'];
      if (rawHome is! Map || rawHome['sections'] is! List) {
        throw const FormatException('Published Home is missing its sections array.');
      }
      final home = Map<String, dynamic>.from(rawHome);
      final sections = (home['sections'] as List)
          .whereType<Map>()
          .map((section) => Map<String, dynamic>.from(section))
          .where((section) => section['visible'] != false)
          .toList(growable: false);
      home['sections'] = sections;
      rawPages['home'] = home;
      value['pages'] = rawPages;

      // Cache only the same published shape that the public Home renderer reads.
      await prefs.setString('glowhit_published_designer_config', jsonEncode(value));
      _sliderFutures.clear();
      if (mounted) setState(() => designerConfig = value);
      debugPrint('[ARK Designer Sync] Published Home v${value['version'] ?? value['published_version'] ?? 'unknown'}: ${sections.length} visible sections');
    } catch (e, stack) {
      debugPrint('[ARK Designer Sync] Failed to fetch published Home: $e');
      debugPrintStack(stackTrace: stack);
      // Keep the last known-good cache only on network/server failure. A valid
      // server response containing [] intentionally clears the Shopping Home.
      if (cached == null && mounted) {
        setState(() => error = 'Could not sync published Home: $e');
      }
    } finally {
      if (mounted) setState(() => designerConfigLoading = false);
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
    final tagId = (section['tag_id'] as num?)?.toInt() ?? 0;
    var rows = products.where((p) {
      if (source == 'sale' || source == 'on_sale') return p['on_sale'] == true;
      if (source == 'featured') return p['is_featured'] == true;
      if (source == 'wishlist') return wishlist.any((w) => w['id'] == p['id']);
      if (source == 'best_selling') return (p['total_sales'] as num?) != null;
      if (source == 'new_arrival' || source == 'latest') return true;
      if (source == 'category' && categoryId > 0) {
        final ids = p['categories'] is List ? (p['categories'] as List).whereType<Map>().map((c) => (c['id'] as num?)?.toInt()).toList() : <int?>[];
        return ids.contains(categoryId);
      }
      if (source == 'tag' && tagId > 0) {
        final ids = p['tags'] is List ? (p['tags'] as List).whereType<Map>().map((tag) => (tag['id'] as num?)?.toInt()).toList() : <int?>[];
        return ids.contains(tagId);
      }
      return true;
    }).toList();
    if (source == 'top_rated') {
      rows.sort((a, b) => ((b['average_rating'] as num?) ?? 0).compareTo((a['average_rating'] as num?) ?? 0));
    } else if (source == 'best_selling') {
      rows.sort((a, b) => ((b['total_sales'] as num?) ?? 0).compareTo((a['total_sales'] as num?) ?? 0));
    } else if (source == 'new_arrival' || source == 'latest') {
      rows.sort((a, b) => (b['date_created'] ?? '').toString().compareTo((a['date_created'] ?? '').toString()));
    }
    final limit = (section['limit'] as num?)?.toInt() ?? 8;
    return rows.take(limit.clamp(1, 40)).toList();
  }

  Widget _designerSection(Map<String, dynamic> section) {
    final imageCacheWidth = (MediaQuery.of(context).size.width *
        MediaQuery.of(context).devicePixelRatio).round().clamp(320, 2048);
    final nested = section['properties'] is Map
        ? Map<String, dynamic>.from(section['properties'] as Map)
        : <String, dynamic>{};
    // DesignerComponent JSON keeps editable values under "properties";
    // legacy WordPress sections keep the same values at the root.
    final config = <String, dynamic>{...section, ...nested};
    final type = normalizeDesignerBannerLayoutType({
      ...config,
      'designer_component_type': nested['designer_component_type'] ??
          nested['type'] ?? config['designer_component_type'] ?? config['type'] ?? '',
    });
    config['designer_component_type'] = type;
    config['visible'] = nested['visible'] ?? config['visible'] ?? config['enabled'] ?? true;
    if (config['visible'] == false) return const SizedBox.shrink();
    final layoutSpec = DesignerLayoutSpec.fromMap(config);
    final title = (config['title'] ?? '').toString();
    final showTitle = config['show_title'] != false && title.isNotEmpty;
    final background = (config['section_background'] ?? 'transparent').toString();
    final backgroundImageUrl = (config['background_image_url'] ?? '').toString().trim();
    final textColor = (config['text_color'] ?? config['title_color'] ?? '#202733').toString();
    TextStyle sectionTitleStyle() {
      final weight = (config['title_font_weight'] ?? 'bold').toString();
      final titleBackground = (config['title_background_color'] ?? '').toString();
      return _designerFontStyle(
        (config['font_family'] ?? 'Roboto').toString(),
        TextStyle(
        color: _safeColor(textColor),
        backgroundColor: titleBackground.isEmpty || titleBackground == '#00000000'
            ? null
            : _safeColor(titleBackground),
        fontSize: (config['title_font_size'] as num?)?.toDouble() ?? 18,
        fontWeight: weight == 'normal' ? FontWeight.normal
            : weight == 'medium' ? FontWeight.w500 : FontWeight.bold,
        fontStyle: config['italic'] == true ? FontStyle.italic : FontStyle.normal,
        fontFamily: (config['font_family'] ?? 'Roboto').toString(),
        letterSpacing: (config['letter_spacing'] as num?)?.toDouble() ?? 0,
        wordSpacing: (config['word_spacing'] as num?)?.toDouble() ?? 0,
      ));
    }
    final padding = layoutSpec.padding.top;
    final paddingLeft = layoutSpec.padding.left;
    final paddingRight = layoutSpec.padding.right;
    final mainAxisGap = layoutSpec.mainAxisSpacing;
    final crossAxisGap = layoutSpec.crossAxisSpacing;
    final margin = layoutSpec.margin;

    if (type == 'ark_live_slider' || type.startsWith('banner_') || config['designer_component_type']?.toString().startsWith('banner_') == true) {
      final key = (config['slider_key'] ?? '').toString();
      final inlineChildren = config['slides'] is List
          ? (config['slides'] as List)
          : (config['children'] is List ? config['children'] as List : const <dynamic>[]);
      final sectionMargin = margin;
      final normalizedInline = inlineChildren.whereType<Map>().map((slide) {
        final item = Map<String, dynamic>.from(slide);
        item['image_url'] = item['image_url'] ?? item['source_url'] ?? item['url'] ?? '';
        return item;
      }).where((slide) => slide['active'] != false &&
          (slide['image_url'] ?? '').toString().trim().isNotEmpty).toList();

      Widget renderCarousel(List<Map<String, dynamic>> slides, Map<String, dynamic> settings) {
        final renderSpec = DesignerLayoutSpec.fromMap(settings.isEmpty ? config : {...config, ...settings});
        final height = renderSpec.height;
        final maxChildWidth = renderSpec.maxCrossAxisExtent ?? MediaQuery.of(context).size.width;
        // Width and viewport fraction are separate Designer controls:
        // width sizes the carousel shell; view_fraction sizes each slide.
        final carouselFraction = ((config['card_width'] ?? config['view_fraction']) as num?)
            ?.toDouble().clamp(.4, 1.0).toDouble() ?? .9;
        final childElevation = renderSpec.elevation;
        final intervalMs = ((settings['interval_ms'] ?? config['interval_ms'] ?? (((config['autoplay_seconds'] as num?)?.toDouble() ?? 4) * 1000)) as num).toInt();
        final layout = (config['designer_component_type'] ?? config['type'] ?? '').toString();
        final bannerGrid = layout == 'banner_grid';
        final bannerGridLimit = ((config['limit'] as num?)?.toInt() ?? 8).clamp(1, 40);
        final bannerGridSlides = slides.take(bannerGridLimit).toList();
        final bannerStyle = layout == 'banner_list' || layout == 'banner_scroll';
        final bannerGridColumns = renderSpec.crossAxisCount;
        final bannerGridAspect = renderSpec.crossAspectRatio.clamp(.4, 3.0);
        final bannerGridRowExtent = (height.clamp(40, 500) * (1.2 / bannerGridAspect)).clamp(40, 600).toDouble();
        final bannerGridRows = (bannerGridSlides.length / bannerGridColumns).ceil().clamp(1, 40);
        final bannerGridHeight = bannerGridRowExtent * bannerGridRows + mainAxisGap * (bannerGridRows - 1);
        return Align(
          alignment: Alignment.center,
          child: Container(
            // Width belongs to each child image/card, not the section shell.
            width: (MediaQuery.of(context).size.width - sectionMargin.horizontal)
                .clamp(0, MediaQuery.of(context).size.width).toDouble(),
            margin: sectionMargin,
            decoration: BoxDecoration(
          color: backgroundImageUrl.isNotEmpty || background == 'transparent' ? null : _safeColor(background),
          image: backgroundImageUrl.isNotEmpty
              ? DecorationImage(image: ResizeImage(NetworkImage(backgroundImageUrl), width: imageCacheWidth), fit: _designerBackgroundFit(config['background_image_fit']), alignment: _designerBackgroundAlignment(config['background_image_alignment']))
              : null,
        ),
            padding: EdgeInsets.fromLTRB(
              paddingLeft,
              padding,
              paddingRight,
              (config['padding_bottom'] as num?)?.toDouble() ?? 12,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showTitle) Padding(
              padding: EdgeInsets.only(
                bottom: (config['title_bottom_spacing'] as num?)?.toDouble() ?? 8,
              ),
              child: Text(title, style: sectionTitleStyle()),
            ),
            bannerGrid
                ? SizedBox(
                    height: bannerGridHeight,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bannerGridSlides.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: bannerGridColumns,
                        crossAxisSpacing: crossAxisGap,
                        mainAxisSpacing: mainAxisGap,
                        mainAxisExtent: bannerGridRowExtent,
                      ),
                      itemBuilder: (_, index) {
                        final slide = bannerGridSlides[index];
                        final url = (slide['image_url'] ?? slide['source_url'] ?? '').toString();
                        return LayoutBuilder(builder: (context, constraints) {
                          final childWidth = renderSpec.childWidthFor(constraints.maxWidth, fallbackMaxCrossAxisExtent: maxChildWidth);
                          return Align(alignment: Alignment.centerLeft, child: SizedBox(width: childWidth, child: Card(
                            margin: EdgeInsets.zero,
                            elevation: childElevation,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(renderSpec.borderRadius.clamp(0, 32).toDouble())),
                            child: InkWell(
                              onTap: () => _openDesignerChildLink(slide),
                              child: url.isEmpty
                                  ? const ColoredBox(color: Color(0xFFEDEAF2), child: Icon(Icons.image_outlined))
                                  : Image.network(url, fit: BoxFit.cover, cacheWidth: imageCacheWidth, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                            ),
                          )));
                        });
                      },
                    ),
                  )
                : bannerStyle
                ? LayoutBuilder(builder: (context, constraints) {
                    // Keep the published Banner Scroll child geometry identical
                    // to Designer preview: size from the inner content viewport,
                    // not the full device width (which ignores section margin/padding).
                    final childWidth = renderSpec.childWidthFor(constraints.maxWidth, fallbackMaxCrossAxisExtent: maxChildWidth);
                    // Banner List is a full vertical stack; Banner Scroll
                    // remains a bounded scroll viewport even when vertical.
                    final verticalList = layout == 'banner_list';
                    Widget buildBannerChild(Map<String, dynamic> slide) {
                      final url = (slide['image_url'] ?? slide['source_url'] ?? '').toString();
                      return SizedBox(
                        width: childWidth,
                        height: height.clamp(40, 500).toDouble(),
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: Colors.white,
                          elevation: childElevation.clamp(0, 12).toDouble(),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(renderSpec.borderRadius.clamp(0, 32).toDouble()),
                          ),
                          child: InkWell(
                            onTap: () => _openDesignerChildLink(slide),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                url.isEmpty
                                    ? const ColoredBox(
                                        color: Color(0xFFEDEAF2),
                                        child: Icon(Icons.image_outlined),
                                      )
                                    : Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        cacheWidth: imageCacheWidth,
                                        gaplessPlayback: true,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image_outlined),
                                      ),
                                if ((slide['title'] ?? '').toString().isNotEmpty)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      color: Colors.black.withValues(alpha: .52),
                                      child: Text(
                                        slide['title'].toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    if (verticalList) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: slides.asMap().entries.map((entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == slides.length - 1 ? 0 : mainAxisGap,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: buildBannerChild(entry.value),
                          ),
                        )).toList(),
                      );
                    }
                    return SizedBox(
                      height: height.clamp(40, 500).toDouble(),
                      child: ListView.separated(
                        scrollDirection: layoutSpec.horizontal ? Axis.horizontal : Axis.vertical,
                        padding: EdgeInsets.zero,
                        itemCount: slides.length,
                        separatorBuilder: (_, __) => renderSpec.horizontal
                            ? SizedBox(width: crossAxisGap)
                            : SizedBox(height: mainAxisGap),
                        itemBuilder: (_, index) => buildBannerChild(slides[index]),
                      ),
                    );
                  })
                : LayoutBuilder(builder: (context, constraints) {
                    final carouselWidth = renderSpec.childWidthFor(constraints.maxWidth, fallbackMaxCrossAxisExtent: maxChildWidth);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: carouselWidth,
                        height: height,
                        child: ArkDesignerBannerCarousel(
                          slides: slides,
                          height: height,
                          radius: renderSpec.borderRadius.clamp(0, 32).toDouble(),
                          autoplay: config['autoplay'] != false,
                          interval: Duration(milliseconds: intervalMs.clamp(1000, 30000)),
                          pauseOnInteraction: config['pause_on_interaction'] != false,
                          showDots: config['control'] != false && config['show_dots'] == true,
                          showArrows: config['control'] != false && config['show_arrows'] == true,
                          fade: config['transition'] == 'fade',
                          viewFraction: carouselFraction,
                          elevation: childElevation.clamp(0, 12).toDouble(),
                          onSlideTap: _openDesignerChildLink,
                        ),
                      ),
                    );
                  }),
              ]),
          ),
        );
      }

      // Inline Designer children are the newest published source of truth.
      // SQL slider data remains a fallback for older sections that have no
      // inline children yet.
      if (normalizedInline.isNotEmpty) {
        return renderCarousel(normalizedInline, section);
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
            if (slides.isEmpty) return SizedBox(height: (config['height_px'] as num?)?.toDouble() ?? 180, child: const Center(child: CircularProgressIndicator()));
            return renderCarousel(slides, settings);
          },
        );
      }
      if ((config['image_url'] ?? '').toString().isNotEmpty) {
        return renderCarousel([
          {'image_url': config['image_url'], 'title': title},
        ], section);
      }
      return const SizedBox.shrink();
    }
    if (type == 'category_grid' || type.startsWith('category_')) {
      final layout = (config['category_layout'] ?? config['layout_variant'] ?? type).toString().toLowerCase();
      final parentId = (config['category_id'] as num?)?.toInt() ?? 0;
      var rows = storeCategories.where((category) {
        if (parentId <= 0) return true;
        final parent = (category['parent'] as num?)?.toInt() ?? 0;
        return parent == parentId;
      }).toList();
      final limit = (config['limit'] as num?)?.toInt() ?? layoutSpec.fixedGridViewCount;
      rows = rows.take(limit.clamp(1, 100)).toList();
      if (rows.isEmpty) return const SizedBox.shrink();
      final cardRadius = layoutSpec.borderRadius.clamp(0, 28).toDouble();
      final cardHeight = layoutSpec.height;
      final childWidthFactor = layoutSpec.widthFactor;
      final categoryCardWidth = layoutSpec.maxCrossAxisExtent ?? 180;
      final categoryAspect = layoutSpec.crossAspectRatio.clamp(.4, 2.5);
      final categoryRowExtent = (cardHeight * (.9 / categoryAspect)).clamp(40, 600).toDouble();
      final cards = rows.map((category) {
        final image = category['image'] is Map ? (category['image'] as Map)['src']?.toString() ?? '' : '';
        final card = Card(
          clipBehavior: Clip.antiAlias,
          elevation: layoutSpec.elevation.clamp(0, 12).toDouble(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: image.isNotEmpty
                  ? Image.network(image, fit: BoxFit.cover, cacheWidth: imageCacheWidth, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.category_outlined)))
                  : const Center(child: Icon(Icons.category_outlined, size: 34)),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Text(
                (category['name'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        );
        return card;
      }).toList();
      return Container(
        width: (MediaQuery.of(context).size.width - margin.horizontal).clamp(0, MediaQuery.of(context).size.width).toDouble(),
        margin: margin,
        decoration: BoxDecoration(
          color: backgroundImageUrl.isNotEmpty || background == 'transparent' ? null : _safeColor(background),
          image: backgroundImageUrl.isNotEmpty
              ? DecorationImage(image: ResizeImage(NetworkImage(backgroundImageUrl), width: imageCacheWidth), fit: _designerBackgroundFit(config['background_image_fit']), alignment: _designerBackgroundAlignment(config['background_image_alignment']))
              : null,
        ),
        padding: EdgeInsets.fromLTRB(
          (config['padding_left'] as num?)?.toDouble() ?? 12,
          padding,
          (config['padding_right'] as num?)?.toDouble() ?? 12,
          (config['padding_bottom'] as num?)?.toDouble() ?? 12,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showTitle) Padding(
            padding: EdgeInsets.only(
              bottom: (config['title_bottom_spacing'] as num?)?.toDouble() ?? 8,
            ),
            child: Text(title, style: sectionTitleStyle()),
          ),
          if (layout.contains('list_tile'))
            Column(children: rows.map((category) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: category['image'] is Map && ((category['image'] as Map)['src'] ?? '').toString().isNotEmpty
                  ? SizedBox(width: 52, height: 52, child: Image.network((category['image'] as Map)['src'].toString(), fit: BoxFit.cover, cacheWidth: imageCacheWidth, gaplessPlayback: true))
                  : const Icon(Icons.category_outlined),
              title: Text((category['name'] ?? '').toString()),
            )).toList())
          else if (layout.contains('list'))
            Column(children: cards.asMap().entries.map((entry) => Padding(
              padding: EdgeInsets.only(bottom: entry.key == cards.length - 1 ? 0 : mainAxisGap),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: categoryCardWidth * childWidthFactor, height: cardHeight, child: entry.value),
              ),
            )).toList())
          else if (layout.contains('slider') || layout.contains('scroll'))
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: layoutSpec.horizontal ? Axis.horizontal : Axis.vertical,
                itemCount: cards.length,
                separatorBuilder: (_, __) => layoutSpec.horizontal
                    ? SizedBox(width: crossAxisGap)
                    : SizedBox(height: mainAxisGap),
                itemBuilder: (_, index) => SizedBox(
                  width: categoryCardWidth * childWidthFactor,
                  height: cardHeight,
                  child: cards[index],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: layoutSpec.crossAxisCount,
                crossAxisSpacing: crossAxisGap,
                mainAxisSpacing: mainAxisGap,
                mainAxisExtent: categoryRowExtent,
              ),
              itemBuilder: (_, index) => LayoutBuilder(
                builder: (context, constraints) {
                  final childWidth = layoutSpec.childWidthFor(constraints.maxWidth, fallbackMaxCrossAxisExtent: categoryCardWidth);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: childWidth, height: categoryRowExtent, child: cards[index]),
                  );
                },
              ),
            ),
        ]),
      );
    }

    if (type == 'product_grid' || type == 'product_carousel' || type.startsWith('product_')) {
      final rows = _designerProducts(config);
      if (rows.isEmpty) return const SizedBox.shrink();
      final layout = (config['layout_variant'] ?? config['designer_component_type'] ?? type).toString().toLowerCase();
      final childWidthFactor = layoutSpec.widthFactor;
      final cardWidth = layoutSpec.maxCrossAxisExtent ?? 174;
      final cardHeight = layoutSpec.height;
      final productAspect = layoutSpec.crossAspectRatio.clamp(.4, 2.5);
      final productRowExtent = (cardHeight * (.66 / productAspect)).clamp(40, 700).toDouble();
      final cardRadius = layoutSpec.borderRadius.clamp(0, 32).toDouble();
      final cardElevation = layoutSpec.elevation;
      final cards = rows.map((product) => SizedBox(
        width: cardWidth * childWidthFactor,
        height: cardHeight,
        child: productCard(product, radius: cardRadius, elevation: cardElevation),
      )).toList();
      return Container(
        width: (MediaQuery.of(context).size.width - margin.horizontal).clamp(0, MediaQuery.of(context).size.width).toDouble(),
        margin: margin,
        decoration: BoxDecoration(
          color: backgroundImageUrl.isNotEmpty || background == 'transparent' ? null : _safeColor(background),
          image: backgroundImageUrl.isNotEmpty
              ? DecorationImage(image: ResizeImage(NetworkImage(backgroundImageUrl), width: imageCacheWidth), fit: _designerBackgroundFit(config['background_image_fit']), alignment: _designerBackgroundAlignment(config['background_image_alignment']))
              : null,
        ),
        padding: EdgeInsets.fromLTRB(
          paddingLeft,
          padding,
          paddingRight,
          (config['padding_bottom'] as num?)?.toDouble() ?? 12,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showTitle) Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: sectionTitleStyle()),
          ),
          if (layout.contains('carousel') || layout.contains('slider') || layout.contains('scroll'))
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: layoutSpec.horizontal ? Axis.horizontal : Axis.vertical,
                itemCount: cards.length,
                separatorBuilder: (_, __) => layoutSpec.horizontal
                  ? SizedBox(width: crossAxisGap)
                  : SizedBox(height: mainAxisGap),
                itemBuilder: (_, index) => cards[index],
              ),
            )
          else if (layout.contains('list'))
            Column(children: rows.asMap().entries.map((entry) => Padding(
              padding: EdgeInsets.only(bottom: entry.key == rows.length - 1 ? 0 : mainAxisGap),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: cardWidth * childWidthFactor,
                  height: cardHeight,
                  child: productCard(entry.value, radius: cardRadius, elevation: cardElevation),
                ),
              ),
            )).toList())
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: layoutSpec.crossAxisCount,
                mainAxisExtent: productRowExtent,
                crossAxisSpacing: crossAxisGap,
                mainAxisSpacing: mainAxisGap,
              ),
              itemBuilder: (_, index) => LayoutBuilder(
                builder: (context, constraints) {
                  final childWidth = layoutSpec.childWidthFor(constraints.maxWidth, fallbackMaxCrossAxisExtent: cardWidth);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: childWidth,
                      height: productRowExtent,
                      child: productCard(rows[index], radius: cardRadius, elevation: cardElevation),
                    ),
                  );
                },
              ),
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

  Map<String, dynamic>? _floatingActionForPage(String pageKey) {
    final raw = designerConfig['floating_actions'];
    if (raw is! Map || raw[pageKey] is! Map) return null;
    final action = Map<String, dynamic>.from(raw[pageKey] as Map);
    return action['enabled'] == true ? action : null;
  }

  Widget? _buildDesignerFloatingAction(String pageKey) {
    final action = _floatingActionForPage(pageKey);
    if (action == null) return null;
    final size = ((action['size'] as num?)?.toDouble() ?? 56).clamp(40.0, 76.0).toDouble();
    final right = ((action['margin_right'] as num?)?.toDouble() ?? 16).clamp(0.0, 120.0).toDouble();
    final bottom = ((action['margin_bottom'] as num?)?.toDouble() ?? 16).clamp(0.0, 120.0);
    final family = (action['icon_family'] ?? 'Material').toString();
    final iconName = (action['icon'] ?? 'add').toString();
    return Padding(
      padding: EdgeInsets.only(right: right, bottom: bottom),
      child: SizedBox(
        width: size,
        height: size,
        child: FloatingActionButton(
          heroTag: 'ark-designer-fab-$pageKey',
          tooltip: (action['tooltip'] ?? '').toString().trim().isEmpty
              ? 'Open action' : action['tooltip'].toString(),
          backgroundColor: _safeColor((action['background_color'] ?? '#5B3A9E').toString()),
          foregroundColor: _safeColor((action['icon_color'] ?? '#FFFFFF').toString()),
          onPressed: () => _handleDesignerFloatingAction(action),
          child: DesignerNavIcons.icon(
            family, iconName,
            color: _safeColor((action['icon_color'] ?? '#FFFFFF').toString()),
            size: size * .43,
          ),
        ),
      ),
    );
  }

  Future<void> _handleDesignerFloatingAction(Map<String, dynamic> action) async {
    final type = (action['link_type'] ?? 'in_app').toString();
    final target = (action['link_value'] ?? '').toString().trim();
    if (target.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a destination for this Floating Action Button in Designer Settings.')),
      );
      return;
    }
    if (type == 'chrome' || type == 'deeplink') {
      final uri = Uri.tryParse(target);
      final allowed = uri != null && uri.scheme.isNotEmpty &&
          (type == 'chrome'
              ? const ['http', 'https'].contains(uri.scheme.toLowerCase()) && uri.host.isNotEmpty
              : const ['http', 'https', 'ark', 'glowhit', 'mailto', 'tel'].contains(uri.scheme.toLowerCase()));
      if (!allowed) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This Floating Action Button link is invalid.')),
        );
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
      return;
    }

    final pageKey = target.replaceFirst(RegExp(r'^page:'), '').trim();
    switch (pageKey) {
      case 'home':
      case 'store':
        if (mounted) setState(() => tab = 0);
        return;
      case 'search':
        if (mounted) {
          setState(() => tab = 0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) FocusScope.of(context).requestFocus(searchFocusNode);
          });
        }
        return;
      case 'categories':
        if (mounted) setState(() => tab = 1);
        return;
      case 'wishlist':
        if (mounted) setState(() => tab = 2);
        return;
      case 'cart':
        if (mounted) setState(() => tab = 3);
        return;
      case 'account':
        if (mounted) setState(() => tab = 4);
        return;
      case 'orders':
        if (customerToken == null || customerToken!.isEmpty) {
          if (mounted) {
            setState(() => tab = 4);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please sign in to view your orders.')),
            );
          }
          return;
        }
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => CustomerSectionPage(
            token: customerToken!,
            section: 'My Orders',
            floatingActionButton: _buildDesignerFloatingAction('orders'),
          ),
        ));
        return;
      case 'notifications':
        await _openNotifications();
        return;
      case 'product':
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open a product first to use its Product page action.')),
        );
        return;
      default:
        final pages = designerConfig['pages'];
        final pageData = pages is Map ? pages[pageKey] : null;
        if (pageData is! Map) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The selected Designer page was not found.')),
          );
          return;
        }
        final sections = pageData['sections'] is List
            ? (pageData['sections'] as List).whereType<Map>()
                .where((section) => section['visible'] != false)
                .map((section) => Map<String, dynamic>.from(section)).toList()
            : <Map<String, dynamic>>[];
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: _buildConfiguredAppBar(pageKey) ?? AppBar(title: Text((pageData['title'] ?? pageKey).toString())),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: sections.map(_designerSection).toList(),
            ),
            floatingActionButton: _buildDesignerFloatingAction(pageKey),
            bottomNavigationBar: _buildDesignerBottomNavigation(),
          ),
        ));
    }
  }

  Widget _designerCatalog() {
    final page = designerConfig['pages'] is Map ? (designerConfig['pages'] as Map)['home'] : null;
    final sections = page is Map && page['sections'] is List
        ? (page['sections'] as List).whereType<Map>()
            .where((section) => section['visible'] != false)
            .map((section) => Map<String, dynamic>.from(section)).toList()
        : const <Map<String, dynamic>>[];
    final sectionWidgets = sections.map(_designerSection).toList();
    return Column(children: [
      Expanded(child: RefreshIndicator(
        onRefresh: _loadDesignerConfig,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            if (designerConfigLoading && sections.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ...sectionWidgets,
          ],
        ),
      )),
    ]);
  }

  Widget catalog() => designerConfig['pages'] is Map && ((designerConfig['pages'] as Map)['home'] is Map) && (((designerConfig['pages'] as Map)['home'] as Map)['sections'] is List)
      ? _designerCatalog()
      : Column(children: [
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
  Future<void> _openNavigationItem(DesignerNavigationItem item, int index) async {
    if (!mounted) return;
    setState(() => selectedNavigationIndex = index);
    final link = item.link.toLowerCase();
    if (const ['home', 'store'].contains(link)) {
      setState(() => tab = 0);
      return;
    }
    if (link == 'categories') {
      setState(() => tab = 1);
      return;
    }
    if (link == 'wishlist') {
      setState(() => tab = 2);
      return;
    }
    if (link == 'cart') {
      setState(() => tab = 3);
      return;
    }
    if (link == 'account') {
      setState(() => tab = 4);
      return;
    }
    if (link == 'search') {
      setState(() => tab = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(searchFocusNode);
      });
      return;
    }
    if (link == 'page') {
      final pageKey = item.linkValue.trim().replaceFirst(RegExp(r'^page:'), '');
      final pages = designerConfig['pages'];
      final pageData = pages is Map ? pages[pageKey] : null;
      if (pageKey.isEmpty || pageData is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This native Page key was not found in the published Designer Pages.')),
        );
        return;
      }
      final sections = pageData['sections'] is List
          ? (pageData['sections'] as List)
              .whereType<Map>()
              .where((section) => section['visible'] != false)
              .map((section) => Map<String, dynamic>.from(section))
              .toList()
          : <Map<String, dynamic>>[];
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: _buildConfiguredAppBar(pageKey) ?? AppBar(title: Text((pageData['title'] ?? item.label).toString())),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: sections.map(_designerSection).toList(),
          ),
          floatingActionButton: _buildDesignerFloatingAction(pageKey),
          bottomNavigationBar: _buildDesignerBottomNavigation(),
        ),
      ));
      return;
    }
    if (link == 'orders') {
      if (customerToken == null || customerToken!.isEmpty) {
        setState(() => tab = 4);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to view your orders.')),
        );
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CustomerSectionPage(
          token: customerToken!, section: 'My Orders',
          floatingActionButton: _buildDesignerFloatingAction('orders'),
        ),
      ));
      return;
    }

    var target = item.linkValue.trim();
    if (target.isEmpty) {
      target = switch (link) {
        'bookings' => '$storeUrl/bookings/',
        'posts' => '$storeUrl/blog/',
        'contact_form_7' => '$storeUrl/contact/',
        _ => '',
      };
    }
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add a Page URL for "${item.label}" in Navigation Bar settings.')),
      );
      return;
    }
    final uri = Uri.tryParse(target.contains('://') ? target : '$storeUrl/${target.replaceFirst(RegExp(r'^/+'), '')}');
    if (uri == null || !const ['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This Navigation link is not a valid HTTP or HTTPS URL.')),
      );
      return;
    }
    if (link == 'page') {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this page.')));
      }
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NavigationWebPage(title: item.label, url: uri.toString()),
    ));
  }

  Future<void> _openSearchPage({String initialQuery = '', bool startVoice = false}) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GlowHitSearchPage(
        initialQuery: initialQuery,
        startVoice: startVoice,
        onOpenProduct: (product) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailsPage(
            product: product,
            onAddToCart: () => _addToCart(product),
            onBuyNow: () => _buyNow(product),
            isWishlisted: wishlist.any((e) => e['id'] == product['id']),
            onWishlist: () => setState(() {
              wishlist.any((e) => e['id'] == product['id'])
                  ? wishlist.removeWhere((e) => e['id'] == product['id'])
                  : wishlist.add(product);
            }),
            appBar: _buildConfiguredAppBar('product'),
            floatingActionButton: _buildDesignerFloatingAction('product'),
          )));
        },
      ),
    ));
  }

  PreferredSizeWidget? _buildConfiguredAppBar(String pageKey) {
    final rawAppBar = designerConfig['app_bar'] is Map
        ? Map<String, dynamic>.from(designerConfig['app_bar'] as Map)
        : <String, dynamic>{};
    rawAppBar['address_label'] = deliveryAddressLabel;
    final config = DesignerAppBarConfig(json: rawAppBar);
    if (!config.enabled || !config.visibleOn(pageKey)) return null;
    final topInset = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: Size.fromHeight(config.renderHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topInset),
          SizedBox(
            height: config.renderHeight,
            child: DesignerAppBarView(
        config: config,
        pageKey: pageKey,
        cartCount: cartCount,
        searchController: searchController,
        searchFocusNode: searchFocusNode,
        onSearchSubmitted: (value) {
          _openSearchPage(initialQuery: value.trim());
        },
        onMenu: () => _openAppBarMenu(pageKey),
        onCart: () {
          if (_isNestedAppBarPage(pageKey)) Navigator.of(context).pop();
          setState(() => tab = 3);
        },
        onSearch: () {
          _openSearchPage(initialQuery: searchController.text);
        },
        onVoiceSearch: () {
          _openSearchPage(initialQuery: searchController.text, startVoice: true);
        },
        onWishlist: () {
          if (_isNestedAppBarPage(pageKey)) Navigator.of(context).pop();
          setState(() => tab = 2);
        },
        onRefresh: () { load(); _refreshCart(); _loadDesignerConfig(); },
        onLocation: () async {
          if (_isNestedAppBarPage(pageKey)) Navigator.of(context).pop();
          if (customerToken == null) { setState(() => tab = 4); return; }
          await Navigator.push(context, MaterialPageRoute(builder: (_) =>
              CustomerSectionPage(token: customerToken!, section: 'Saved Addresses', appBar: _buildConfiguredAppBar('account'))));
        },
        onCustomAction: (action) {
          if (_isNestedAppBarPage(pageKey) && (action['link_type'] ?? 'page') == 'page') Navigator.of(context).pop();
          _openAppBarCustomAction(action);
        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignerBottomNavigation() {
    final config = DesignerNavigationConfig.fromJson(designerConfig['navigation_bar']);
    final items = config.items.take(5).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final safeIndex = selectedNavigationIndex.clamp(0, items.length - 1);
    return BottomNavigationBar(
      currentIndex: safeIndex,
      onTap: (index) => _openNavigationItem(items[index], index),
      type: config.type == 'shifting' ? BottomNavigationBarType.shifting : BottomNavigationBarType.fixed,
      backgroundColor: navColorFromHex(config.backgroundColor),
      selectedItemColor: navColorFromHex(config.selectedColor, fallback: purple),
      unselectedItemColor: navColorFromHex(config.unselectedColor, fallback: Colors.grey),
      showSelectedLabels: config.showLabels,
      showUnselectedLabels: config.showLabels,
      elevation: config.elevation,
      items: items.map((item) {
        final isCart = item.link == 'cart';
        Widget withCartBadge(Widget child) {
          if (!isCart || cartCount <= 0) return child;
          return Badge(label: Text('$cartCount'), child: child);
        }
        return BottomNavigationBarItem(
          icon: withCartBadge(DesignerNavIcons.icon(item.iconFamily, item.iconName, color: navColorFromHex(item.iconColor))),
          activeIcon: withCartBadge(DesignerNavIcons.icon(item.activeIconFamily, item.activeIconName, color: navColorFromHex(item.activeIconColor))),
          label: item.label,
          backgroundColor: navColorFromHex(item.activeBackgroundColor),
        );
      }).toList(),
    );
  }

  Widget account() => AccountPanel(ordersAppBar: _buildConfiguredAppBar('orders'), onLogin: (token) { setState(() => customerToken = token); push.register(customerJwt: token); }, onLogout: () async { final token = customerToken; if (token != null) { try { await ArkCustomerApi(token).request('customer/logout', method: 'POST'); } catch (_) {} } try { await push.unlinkAccount(); } catch (_) {} final prefs = await SharedPreferences.getInstance(); await prefs.remove('glowhit_customer_session'); if (mounted) setState(() { customerToken = null; notificationCount = 0; }); }, token: customerToken, onRecentViewed: _openRecentlyViewed, ordersFloatingActionButton: _buildDesignerFloatingAction('orders'));
  @override Widget build(BuildContext context) {
    final titles = ['Shopping', 'Categories', 'Wishlist', 'Cart', 'Account'];
    Widget page;
    if (tab == 0) page = catalog();
    else if (tab == 1) page = const Center(child: Text('Product categories are available from the store catalog.'));
    else if (tab == 2) page = wishlist.isEmpty ? const Center(child: Text('Your wishlist is empty')) : GridView.count(crossAxisCount: 2, childAspectRatio: .66, children: wishlist.map(productCard).toList());
    else if (tab == 3) page = _cartPage();
    else page = account();
    final currentPageKey = tab == 0 ? (searchFocusNode.hasFocus ? 'search' : 'home') : tab == 1 ? 'categories' : tab == 2 ? 'wishlist' : tab == 3 ? 'cart' : 'account';
    final PreferredSizeWidget activeAppBar = _buildConfiguredAppBar(currentPageKey) ?? AppBar(title: Text(titles[tab]), actions: [
      if (tab == 0) IconButton(tooltip: 'ARK Designer', onPressed: _openDesigner, icon: const Icon(Icons.design_services_rounded)),
      if (tab == 0) IconButton(tooltip: 'Sync published layout', onPressed: _loadDesignerConfig, icon: const Icon(Icons.sync_rounded)),
      if (tab == 0) IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      IconButton(
        tooltip: 'Notifications',
        onPressed: _openNotifications,
        icon: Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_none_rounded),
          if (notificationCount > 0) Positioned(right: -2, top: -2, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5))))),
        ]),
      ),
    ]);
    return PopScope<void>(
      canPop: tab == 0 && !searchFocusNode.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (searchFocusNode.hasFocus) {
          searchFocusNode.unfocus();
          return;
        }
        if (tab != 0) setState(() => tab = 0);
      },
      child: Scaffold(
      appBar: activeAppBar,
      body: SafeArea(top: false, child: page),
      floatingActionButton: _buildDesignerFloatingAction(
        tab == 0 ? (searchFocusNode.hasFocus ? 'search' : 'home')
          : tab == 1 ? 'categories' : tab == 2 ? 'wishlist' : tab == 3 ? 'cart' : 'account',
      ),
      bottomNavigationBar: _buildDesignerBottomNavigation()),
    );
  }
}

class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, required this.onLogin, required this.onLogout, required this.token, required this.onRecentViewed, this.ordersFloatingActionButton, this.ordersAppBar});
  final ValueChanged<String> onLogin;
  final VoidCallback onLogout;
  final VoidCallback onRecentViewed;
  final String? token;
  final Widget? ordersFloatingActionButton;
  final PreferredSizeWidget? ordersAppBar;
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
        _menuTile(context, Icons.receipt_long_rounded, 'My Orders', 'Track, cancel and review your purchases', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerSectionPage(token: widget.token!, section: 'My Orders', floatingActionButton: widget.ordersFloatingActionButton, appBar: widget.ordersAppBar)))),
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
                Expanded(child: SizedBox(width: double.infinity, child: image.isEmpty ? const Icon(Icons.shopping_bag_outlined, size: 42) : Image.network(image, fit: BoxFit.contain, cacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio / 2).round().clamp(200, 1200), gaplessPlayback: true, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)))),
                Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 2), child: Text((item['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 10), child: Text(amount, style: const TextStyle(color: purple, fontWeight: FontWeight.w800))),
              ]),
            ));
          },
        ),
  );
}
