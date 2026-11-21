import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WooStoreApi {
  WooStoreApi({this.baseUrl = 'https://pluginstore.shop'});
  final String baseUrl;
  static const _tokenKey = 'glowhit_wc_cart_token';
  String? _cartToken;
  String? nonce;

  Uri _uri(String path) => Uri.parse(baseUrl).resolve('wp-json/wc/store/v1/$path');
  String? _header(http.Response response, String name) {
    for (final entry in response.headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return null;
  }

  Future<void> _captureSession(http.Response response) async {
    final token = _header(response, 'Cart-Token');
    if (token != null && token.isNotEmpty) {
      _cartToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }
    nonce = _header(response, 'Nonce') ?? _header(response, 'X-WC-Store-API-Nonce') ?? nonce;
  }

  Future<Map<String, dynamic>> _send(String path, {
    String method = 'GET',
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool ensureCart = true,
  }) async {
    if (ensureCart && _cartToken == null) await initialiseCart();
    final uri = _uri(path).replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (_cartToken != null) headers['Cart-Token'] = _cartToken!;
    if (nonce != null) {
      headers['Nonce'] = nonce!;
      headers['X-WC-Store-API-Nonce'] = nonce!;
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final client = http.Client();
    try {
      final streamed = await client.send(request).timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 25));
      await _captureSession(response);
      dynamic decoded;
      try {
        decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      } catch (_) {
        throw Exception('WooCommerce returned an invalid response (HTTP ${response.statusCode}).');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map ? (decoded['message'] ?? decoded['code'] ?? response.body) : response.body;
        throw Exception('Store API ${response.statusCode}: $message');
      }
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Unexpected WooCommerce response format.');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> initialiseCart({bool reset = false}) async {
    if (reset) {
      _cartToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    }
    if (_cartToken == null) {
      final prefs = await SharedPreferences.getInstance();
      _cartToken = prefs.getString(_tokenKey);
    }
    final cart = await _send('cart', ensureCart: false);
    if (_cartToken == null && nonce == null) {
      throw Exception('WooCommerce returned neither Cart-Token nor Nonce. Check Store API/session configuration on pluginstore.shop.');
    }
    return cart;
  }

  Future<Map<String, dynamic>> getCart() => _send('cart');
  Future<Map<String, dynamic>> addItem(int productId, {int quantity = 1}) =>
      _send('cart/add-item', method: 'POST', body: {'id': productId, 'quantity': quantity});
  Future<Map<String, dynamic>> updateItem(String key, int quantity) =>
      _send('cart/update-item', method: 'POST', body: {'key': key, 'quantity': quantity});
  Future<Map<String, dynamic>> removeItem(String key) =>
      _send('cart/remove-item', method: 'POST', body: {'key': key});

  Future<Map<String, dynamic>> updateCustomer({required Map<String, dynamic> billing, required Map<String, dynamic> shipping}) =>
      _send('cart/update-customer', method: 'POST', body: {'billing_address': billing, 'shipping_address': shipping});

  Future<Map<String, dynamic>> selectShippingRate(int packageId, String rateId) =>
      _send('cart/select-shipping-rate', method: 'POST', body: {'package_id': packageId, 'rate_id': rateId});

  Future<Map<String, dynamic>> getCheckout() => _send('checkout');

  Future<Map<String, dynamic>> placeOrder({
    required Map<String, dynamic> billing,
    required Map<String, dynamic> shipping,
    required String paymentMethod,
    String customerNote = '',
    List<Map<String, dynamic>> paymentData = const [],
  }) => _send('checkout', method: 'POST', body: {
    'billing_address': billing,
    'shipping_address': shipping,
    'payment_method': paymentMethod,
    'payment_data': paymentData,
    'customer_note': customerNote,
  });
}
