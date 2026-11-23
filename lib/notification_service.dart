import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _pushBase = 'https://pluginstore.shop/wp-json/ark-push/v1';

@pragma('vm:entry-point')
Future<void> glowHitFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class GlowHitPushService {
  GlowHitPushService({required this.onTap, required this.onForeground});
  final void Function(String?) onTap;
  final VoidCallback onForeground;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ark_promotions', 'GlowHit Notifications',
    description: 'Order updates and store notifications',
    importance: Importance.high,
  );
  String? _token;
  String? _customerJwt;
  bool _ready = false;

  Future<void> initialize({String? customerJwt}) async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(glowHitFirebaseBackgroundHandler);
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      await _local.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (response) => onTap(response.payload),
      );
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
      FirebaseMessaging.onMessage.listen((message) async {
        onForeground();
        final title = message.notification?.title ?? message.data['title']?.toString() ?? 'GlowHit';
        final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
        await _local.show(message.hashCode, title, body,
          NotificationDetails(android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description, importance: Importance.high, priority: Priority.high, icon: '@mipmap/ic_launcher')),
          payload: message.data['click_url']?.toString());
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) => onTap(message.data['click_url']?.toString()));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) onTap(initial.data['click_url']?.toString());
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await register(customerJwt: customerJwt);
      _customerJwt = customerJwt;
      FirebaseMessaging.instance.onTokenRefresh.listen((value) async {
        _token = value;
        await register(customerJwt: _customerJwt);
      });
      _ready = true;
    } catch (_) { _ready = false; }
  }

  Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('ark_push_installation_id');
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('ark_push_installation_id', id);
    }
    return id;
  }

  Future<http.Response> _requestWithRestFallback({
    required String path,
    required String method,
    required Map<String, String> headers,
    String? body,
  }) async {
    Future<http.Response> send(Uri uri) async {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = body;
      final client = http.Client();
      try {
        final streamed = await client.send(request).timeout(const Duration(seconds: 20));
        return await http.Response.fromStream(streamed).timeout(const Duration(seconds: 20));
      } finally {
        client.close();
      }
    }

    final prettyUri = Uri.parse(_pushBase + '/' + path);
    final response = await send(prettyUri);
    if (response.statusCode != 404 && response.statusCode != 405) return response;

    // Some WordPress/hosting configurations do not rewrite pretty REST URLs.
    // Retry the same authenticated request through WordPress' rest_route query.
    final fallbackUri = Uri.parse('https://pluginstore.shop/').replace(
      queryParameters: {'rest_route': '/ark-push/v1/' + path},
    );
    return send(fallbackUri);
  }

  Future<void> register({String? customerJwt}) async {
    if (customerJwt != null) _customerJwt = customerJwt;
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    _token = token;
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (customerJwt != null && customerJwt.isNotEmpty) headers['Authorization'] = 'Bearer ' + customerJwt;
    final response = await _requestWithRestFallback(
      path: 'register',
      method: 'POST',
      headers: headers,
      body: jsonEncode({
        'token': token, 'platform': 'android', 'app_version': '1.0.10+90', 'installation_id': await _installationId(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('FCM registration failed (' + response.statusCode.toString() + ')');
  }

  Future<List<Map<String, dynamic>>> loadInbox() async {
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return [];
    _token = token;
    final response = await _requestWithRestFallback(
      path: 'messages',
      method: 'GET',
      headers: {'Accept': 'application/json', 'x-ark-push-token': token},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Notification inbox unavailable (' + response.statusCode.toString() + ')');
    final decoded = jsonDecode(response.body);
    final rows = decoded is Map ? decoded['messages'] : null;
    if (rows is! List) return [];
    final clean = <Map<String, dynamic>>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final id = int.tryParse((row['id'] ?? '').toString()) ?? 0;
      final title = (row['title'] ?? '').toString().trim();
      final message = (row['body'] ?? '').toString().trim();
      if (id < 1 || title.isEmpty || message.isEmpty) continue;
      row['title'] = title;
      row['body'] = message;
      clean.add(row);
    }
    return clean.take(6).toList();
  }

  Future<void> recordClick(int id) async {
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty || id < 1) return;
    final response = await _requestWithRestFallback(
      path: 'click',
      method: 'POST',
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'x-ark-push-token': token},
      body: jsonEncode({'message_id': id}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not record notification click (' + response.statusCode.toString() + ').');
    }
  }

  Future<void> deleteMessage(int id) async {
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null) throw Exception('Device is not registered.');
    final response = await _requestWithRestFallback(
      path: 'messages/delete',
      method: 'POST',
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'x-ark-push-token': token},
      body: jsonEncode({'message_id': id}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Delete notification failed (' + response.statusCode.toString() + '). Update the ARK Notifications plugin.');
  }

  Future<void> unlinkAccount() async {
    // Re-register this installation as a guest on logout so the previous
    // customer's private order alerts are no longer routed to this device.
    _customerJwt = null;
    await register();
  }

  bool get isReady => _ready;
}
