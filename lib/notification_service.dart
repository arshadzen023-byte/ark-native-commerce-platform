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

  Future<void> register({String? customerJwt}) async {
    if (customerJwt != null) _customerJwt = customerJwt;
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    _token = token;
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json'};
    if (customerJwt != null && customerJwt.isNotEmpty) headers['Authorization'] = 'Bearer ' + customerJwt;
    final response = await http.post(Uri.parse(_pushBase + '/register'), headers: headers, body: jsonEncode({
      'token': token, 'platform': 'android', 'app_version': '1.0.8+88', 'installation_id': await _installationId(),
    })).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('FCM registration failed (' + response.statusCode.toString() + ')');
  }

  Future<List<Map<String, dynamic>>> loadInbox() async {
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return [];
    _token = token;
    final response = await http.get(Uri.parse(_pushBase + '/messages'), headers: {'Accept': 'application/json', 'x-ark-push-token': token}).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Notification inbox unavailable (' + response.statusCode.toString() + ')');
    final decoded = jsonDecode(response.body);
    final rows = decoded is Map ? decoded['messages'] : null;
    if (rows is! List) return [];
    return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).take(6).toList();
  }

  Future<void> deleteMessage(int id) async {
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null) throw Exception('Device is not registered.');
    final response = await http.delete(Uri.parse(_pushBase + '/messages/' + id.toString()), headers: {'Accept': 'application/json', 'x-ark-push-token': token}).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Delete notification failed (' + response.statusCode.toString() + '). The WordPress plugin must expose DELETE /messages/{id}.');
  }

  bool get isReady => _ready;
}
