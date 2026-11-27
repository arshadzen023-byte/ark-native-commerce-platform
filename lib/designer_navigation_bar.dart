import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:remixicon/remixicon.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _navPurple = Color(0xFF5B3A9E);
const _navText = Color(0xFF24212B);
const _navBorder = Color(0xFFE8E5ED);

Color navColorFromHex(dynamic value, {Color fallback = Colors.white}) {
  final raw = (value ?? '').toString().replaceFirst('#', '').trim();
  final parsed = int.tryParse(raw, radix: 16);
  if (parsed == null) return fallback;
  if (raw.length == 6) return Color(0xFF000000 | parsed);
  if (raw.length == 8) return Color(parsed);
  return fallback;
}

String navColorToHex(Color color) =>
    '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

class DesignerNavigationItem {
  DesignerNavigationItem({
    required this.id,
    required this.label,
    required this.link,
    this.linkValue = '',
    this.iconFamily = 'Material',
    this.iconName = 'home_outlined',
    this.activeIconFamily = 'Material',
    this.activeIconName = 'home',
    this.iconColor = '#77717F',
    this.activeIconColor = '#5B3A9E',
    this.itemBackgroundColor = '#FFFFFF',
    this.activeBackgroundColor = '#EDE7F8',
  });

  final String id;
  String label;
  String link;
  String linkValue;
  String iconFamily;
  String iconName;
  String activeIconFamily;
  String activeIconName;
  String iconColor;
  String activeIconColor;
  String itemBackgroundColor;
  String activeBackgroundColor;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'link': link,
    'link_value': linkValue,
    'icon_family': iconFamily,
    'icon': iconName,
    'active_icon_family': activeIconFamily,
    'active_icon': activeIconName,
    'icon_color': iconColor,
    'active_icon_color': activeIconColor,
    'background_color': itemBackgroundColor,
    'active_background_color': activeBackgroundColor,
  };

  factory DesignerNavigationItem.fromJson(Map<String, dynamic> json) =>
      DesignerNavigationItem(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
        label: (json['label'] ?? 'New Button').toString(),
        link: (json['link'] ?? 'home').toString(),
        linkValue: (json['link_value'] ?? '').toString(),
        iconFamily: (json['icon_family'] ?? 'Material').toString(),
        iconName: (json['icon'] ?? 'home_outlined').toString(),
        activeIconFamily: (json['active_icon_family'] ?? json['icon_family'] ?? 'Material').toString(),
        activeIconName: (json['active_icon'] ?? json['icon'] ?? 'home').toString(),
        iconColor: (json['icon_color'] ?? '#77717F').toString(),
        activeIconColor: (json['active_icon_color'] ?? '#5B3A9E').toString(),
        itemBackgroundColor: (json['background_color'] ?? '#FFFFFF').toString(),
        activeBackgroundColor: (json['active_background_color'] ?? '#EDE7F8').toString(),
      );
}

class DesignerNavigationConfig {
  DesignerNavigationConfig({
    List<DesignerNavigationItem>? items,
    this.type = 'fixed',
    this.backgroundColor = '#FFFFFF',
    this.selectedColor = '#5B3A9E',
    this.unselectedColor = '#77717F',
    this.showLabels = true,
    this.elevation = 8,
  }) : items = items ?? defaultItems();

  List<DesignerNavigationItem> items;
  String type;
  String backgroundColor;
  String selectedColor;
  String unselectedColor;
  bool showLabels;
  double elevation;

  static List<DesignerNavigationItem> defaultItems() => [
    DesignerNavigationItem(id: 'nav-home', label: 'Home', link: 'home', iconName: 'home_outlined', activeIconName: 'home'),
    DesignerNavigationItem(id: 'nav-categories', label: 'Categories', link: 'categories', iconName: 'grid_view', activeIconName: 'grid_view'),
    DesignerNavigationItem(id: 'nav-wishlist', label: 'Wishlist', link: 'wishlist', iconName: 'favorite_border', activeIconName: 'favorite'),
    DesignerNavigationItem(id: 'nav-cart', label: 'Cart', link: 'cart', iconName: 'shopping_bag_outlined', activeIconName: 'shopping_bag'),
    DesignerNavigationItem(id: 'nav-account', label: 'Account', link: 'account', iconName: 'person_outline', activeIconName: 'person'),
  ];

  Map<String, dynamic> toJson() => {
    'version': 1,
    'type': type,
    'background_color': backgroundColor,
    'selected_color': selectedColor,
    'unselected_color': unselectedColor,
    'show_labels': showLabels,
    'elevation': elevation,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory DesignerNavigationConfig.fromJson(dynamic value) {
    if (value is! Map) return DesignerNavigationConfig();
    final json = Map<String, dynamic>.from(value);
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map>().map((e) => DesignerNavigationItem.fromJson(Map<String, dynamic>.from(e))).toList()
        : defaultItems();
    return DesignerNavigationConfig(
      items: items.isEmpty ? defaultItems() : items,
      type: (json['type'] ?? 'fixed').toString() == 'shifting' ? 'shifting' : 'fixed',
      backgroundColor: (json['background_color'] ?? '#FFFFFF').toString(),
      selectedColor: (json['selected_color'] ?? '#5B3A9E').toString(),
      unselectedColor: (json['unselected_color'] ?? '#77717F').toString(),
      showLabels: json['show_labels'] != false,
      elevation: (json['elevation'] as num?)?.toDouble() ?? 8,
    );
  }


  /// Describes the exact Navigation Bar fields that WordPress changed or dropped.
  /// This keeps publish verification strict while making Bridge contract failures
  /// actionable instead of returning one opaque JSON mismatch.
  List<String> differencesFrom(DesignerNavigationConfig other) {
    final differences = <String>[];
    final requested = toJson();
    final published = other.toJson();
    for (final key in const [
      'type',
      'background_color',
      'selected_color',
      'unselected_color',
      'show_labels',
      'elevation',
    ]) {
      if (jsonEncode(requested[key]) != jsonEncode(published[key])) {
        differences.add('$key (Designer: ${requested[key]}, WordPress: ${published[key]})');
      }
    }
    final requestedItems = requested['items'] as List;
    final publishedItems = published['items'] as List;
    if (requestedItems.length != publishedItems.length) {
      differences.add('items count (Designer: ${requestedItems.length}, WordPress: ${publishedItems.length})');
    }
    final itemFields = const [
      'id',
      'label',
      'link',
      'link_value',
      'icon_family',
      'icon',
      'active_icon_family',
      'active_icon',
      'icon_color',
      'active_icon_color',
      'background_color',
      'active_background_color',
    ];
    final count = requestedItems.length < publishedItems.length
        ? requestedItems.length
        : publishedItems.length;
    for (var index = 0; index < count; index++) {
      final before = Map<String, dynamic>.from(requestedItems[index] as Map);
      final after = Map<String, dynamic>.from(publishedItems[index] as Map);
      for (final key in itemFields) {
        if (jsonEncode(before[key]) != jsonEncode(after[key])) {
          differences.add('items[$index].$key (Designer: ${before[key]}, WordPress: ${after[key]})');
        }
      }
    }
    return differences;
  }

  DesignerNavigationConfig clone() => DesignerNavigationConfig.fromJson(toJson());
}

class NavIconChoice {
  const NavIconChoice(this.family, this.name, this.label, this.data);
  final String family;
  final String name;
  final String label;
  final dynamic data;
}

class DesignerNavIcons {
  static const families = ['Material', 'Cupertino', 'Font Awesome', 'Remix Icons', 'FluentUI'];

  static const categories = ['All', 'Nature', 'Transport', 'Water', 'Weather', 'E-commerce', 'Social', 'Buildings', 'Digital', 'Internet'];

  static String categoryFor(NavIconChoice choice) {
    final value = ('${choice.name} ${choice.label}').toLowerCase();
    bool has(List<String> words) => words.any(value.contains);
    if (has(['water', 'wave', 'pool', 'beach', 'drop', 'ferry'])) return 'Water';
    if (has(['flight', 'plane', 'train', 'railway', 'metro', 'subway', 'bus', 'car', 'boat', 'ship', 'truck', 'shuttle', 'motorcycle', 'bicycle', 'bike', 'sailing', 'ev_station', 'fuel'])) return 'Transport';
    if (has(['cloud', 'sun', 'moon', 'weather', 'thunder', 'snow', 'wind', 'air', 'night', 'sky', 'rain', 'storm'])) return 'Weather';
    if (has(['nature', 'leaf', 'tree', 'park', 'forest', 'grass', 'eco', 'pet', 'agriculture', 'flower', 'plant'])) return 'Nature';
    if (has(['shopping', 'cart', 'bag', 'basket', 'store', 'mall', 'inventory', 'delivery', 'payment', 'credit', 'wallet', 'rupee', 'currency', 'price', 'sale', 'discount', 'gift', 'qr', 'loyalty', 'point_of_sale'])) return 'E-commerce';
    if (has(['instagram', 'facebook', 'whatsapp', 'youtube', 'telegram', 'linkedin', 'pinterest', 'reddit', 'snapchat', 'discord', 'github', 'tiktok', 'share', 'group', 'chat', 'email', 'call', 'video', 'camera', 'image', 'movie', 'music', 'podcast', 'news', 'rss', 'forum', 'contact'])) return 'Social';
    if (has(['wifi', 'router', 'internet', 'globe', 'network', 'language', 'public', 'web', 'browser'])) return 'Internet';
    if (has(['smartphone', 'computer', 'laptop', 'device', 'memory', 'hub', 'database', 'code', 'terminal', 'security', 'lock', 'key', 'server', 'analytics', 'chart', 'dashboard', 'settings', 'cloud_upload', 'cloud_download'])) return 'Digital';
    if (has(['home', 'house', 'apartment', 'building', 'business', 'bank', 'hotel', 'restaurant', 'cafe', 'school', 'hospital', 'church', 'factory', 'warehouse', 'city', 'location', 'map', 'office', 'work'])) return 'Buildings';
    return 'All';
  }

  static final List<NavIconChoice> all = [
    const NavIconChoice('Material', 'home_outlined', 'Home', Icons.home_outlined),
    const NavIconChoice('Material', 'home', 'Home Filled', Icons.home),
    const NavIconChoice('Material', 'grid_view', 'Grid View', Icons.grid_view),
    const NavIconChoice('Material', 'apps', 'Apps', Icons.apps),
    const NavIconChoice('Material', 'favorite_border', 'Heart Outline', Icons.favorite_border),
    const NavIconChoice('Material', 'favorite', 'Heart Filled', Icons.favorite),
    const NavIconChoice('Material', 'shopping_bag_outlined', 'Shopping Bag', Icons.shopping_bag_outlined),
    const NavIconChoice('Material', 'shopping_bag', 'Shopping Bag Filled', Icons.shopping_bag),
    const NavIconChoice('Material', 'shopping_cart_outlined', 'Cart', Icons.shopping_cart_outlined),
    const NavIconChoice('Material', 'person_outline', 'Person', Icons.person_outline),
    const NavIconChoice('Material', 'person', 'Person Filled', Icons.person),
    const NavIconChoice('Material', 'search', 'Search', Icons.search),
    const NavIconChoice('Material', 'receipt_long', 'Orders', Icons.receipt_long),
    const NavIconChoice('Material', 'calendar_month', 'Calendar', Icons.calendar_month),
    const NavIconChoice('Material', 'storefront', 'Store', Icons.storefront),
    const NavIconChoice('Material', 'article_outlined', 'Posts', Icons.article_outlined),
    const NavIconChoice('Material', 'contact_support_outlined', 'Contact', Icons.contact_support_outlined),
    const NavIconChoice('Material', 'notifications_none', 'Notifications', Icons.notifications_none),
    const NavIconChoice('Material', 'more_horiz', 'More', Icons.more_horiz),

    // Music, websites, payment methods and extra vehicle choices
    const NavIconChoice('Material', 'audiotrack', 'Audio Track', Icons.audiotrack),
    const NavIconChoice('Material', 'library_music', 'Music Library', Icons.library_music),
    const NavIconChoice('Material', 'music_video', 'Music Video', Icons.music_video),
    const NavIconChoice('Material', 'headphones', 'Headphones', Icons.headphones),
    const NavIconChoice('Material', 'speaker', 'Speaker', Icons.speaker),
    const NavIconChoice('Material', 'web', 'Website', Icons.web),
    const NavIconChoice('Material', 'web_asset', 'Web Page', Icons.web_asset),
    const NavIconChoice('Material', 'link', 'Website Link', Icons.link),
    const NavIconChoice('Material', 'payment', 'Payment', Icons.payment),
    const NavIconChoice('Material', 'credit_score', 'Card Payment', Icons.credit_score),
    const NavIconChoice('Material', 'directions_car_filled', 'Car Filled', Icons.directions_car_filled),
    const NavIconChoice('Material', 'commute', 'Commute', Icons.commute),
    const NavIconChoice('Material', 'local_taxi', 'Taxi', Icons.local_taxi),
    const NavIconChoice('Material', 'flight_land', 'Flight Landing', Icons.flight_land),
    const NavIconChoice('Material', 'electric_bike', 'Electric Bike', Icons.electric_bike),
    const NavIconChoice('Material', 'directions_walk', 'Walking', Icons.directions_walk),
    // Transport
    const NavIconChoice('Material', 'flight', 'Flight', Icons.flight),
    const NavIconChoice('Material', 'flight_takeoff', 'Flight Takeoff', Icons.flight_takeoff),
    const NavIconChoice('Material', 'train', 'Train', Icons.train),
    const NavIconChoice('Material', 'directions_subway', 'Metro', Icons.directions_subway),
    const NavIconChoice('Material', 'directions_railway', 'Railway', Icons.directions_railway),
    const NavIconChoice('Material', 'directions_bus', 'Bus', Icons.directions_bus),
    const NavIconChoice('Material', 'directions_car', 'Car', Icons.directions_car),
    const NavIconChoice('Material', 'directions_boat', 'Boat', Icons.directions_boat),
    const NavIconChoice('Material', 'local_shipping', 'Delivery Truck', Icons.local_shipping),
    const NavIconChoice('Material', 'airport_shuttle', 'Airport Shuttle', Icons.airport_shuttle),
    const NavIconChoice('Material', 'two_wheeler', 'Motorcycle', Icons.two_wheeler),
    const NavIconChoice('Material', 'pedal_bike', 'Bicycle', Icons.pedal_bike),
    const NavIconChoice('Material', 'electric_car', 'Electric Car', Icons.electric_car),
    const NavIconChoice('Material', 'ev_station', 'EV Charging', Icons.ev_station),
    const NavIconChoice('Material', 'local_gas_station', 'Fuel Station', Icons.local_gas_station),
    const NavIconChoice('Material', 'sailing', 'Sailing', Icons.sailing),
    // Nature, water and weather
    const NavIconChoice('Material', 'water_drop', 'Water', Icons.water_drop),
    const NavIconChoice('Material', 'waves', 'Waves', Icons.waves),
    const NavIconChoice('Material', 'pool', 'Pool', Icons.pool),
    const NavIconChoice('Material', 'beach_access', 'Beach', Icons.beach_access),
    const NavIconChoice('Material', 'park', 'Park', Icons.park),
    const NavIconChoice('Material', 'forest', 'Forest', Icons.forest),
    const NavIconChoice('Material', 'nature', 'Nature', Icons.nature),
    const NavIconChoice('Material', 'eco', 'Eco', Icons.eco),
    const NavIconChoice('Material', 'grass', 'Grass', Icons.grass),
    const NavIconChoice('Material', 'pets', 'Pets', Icons.pets),
    const NavIconChoice('Material', 'agriculture', 'Agriculture', Icons.agriculture),
    const NavIconChoice('Material', 'cloud', 'Cloud', Icons.cloud),
    const NavIconChoice('Material', 'cloud_queue', 'Cloud Weather', Icons.cloud_queue),
    const NavIconChoice('Material', 'wb_sunny', 'Sunny', Icons.wb_sunny),
    const NavIconChoice('Material', 'thunderstorm', 'Thunderstorm', Icons.thunderstorm),
    const NavIconChoice('Material', 'ac_unit', 'Snow / Cooling', Icons.ac_unit),
    const NavIconChoice('Material', 'air', 'Air', Icons.air),
    const NavIconChoice('Material', 'wind_power', 'Wind Power', Icons.wind_power),
    const NavIconChoice('Material', 'nightlight', 'Night', Icons.nightlight),
    const NavIconChoice('Material', 'dark_mode', 'Dark Mode', Icons.dark_mode),
    // E-commerce, shopping and payments
    const NavIconChoice('Material', 'store', 'Store', Icons.store),
    const NavIconChoice('Material', 'local_mall', 'Mall', Icons.local_mall),
    const NavIconChoice('Material', 'shopping_basket', 'Basket', Icons.shopping_basket),
    const NavIconChoice('Material', 'inventory_2', 'Inventory', Icons.inventory_2),
    const NavIconChoice('Material', 'delivery_dining', 'Delivery', Icons.delivery_dining),
    const NavIconChoice('Material', 'payments', 'Payments', Icons.payments),
    const NavIconChoice('Material', 'credit_card', 'Credit Card', Icons.credit_card),
    const NavIconChoice('Material', 'account_balance_wallet', 'Wallet', Icons.account_balance_wallet),
    const NavIconChoice('Material', 'currency_rupee', 'Rupee', Icons.currency_rupee),
    const NavIconChoice('Material', 'currency_exchange', 'Currency Exchange', Icons.currency_exchange),
    const NavIconChoice('Material', 'price_check', 'Price Check', Icons.price_check),
    const NavIconChoice('Material', 'point_of_sale', 'Point of Sale', Icons.point_of_sale),
    const NavIconChoice('Material', 'sell', 'Sell', Icons.sell),
    const NavIconChoice('Material', 'discount', 'Discount', Icons.discount),
    const NavIconChoice('Material', 'redeem', 'Gift / Redeem', Icons.redeem),
    const NavIconChoice('Material', 'card_giftcard', 'Gift Card', Icons.card_giftcard),
    const NavIconChoice('Material', 'qr_code', 'QR Code', Icons.qr_code),
    const NavIconChoice('Material', 'qr_code_scanner', 'QR Scanner', Icons.qr_code_scanner),
    const NavIconChoice('Material', 'loyalty', 'Loyalty', Icons.loyalty),
    // Social, communication and media
    const NavIconChoice('Material', 'share', 'Share', Icons.share),
    const NavIconChoice('Material', 'groups', 'Groups', Icons.groups),
    const NavIconChoice('Material', 'person_add', 'Add Person', Icons.person_add),
    const NavIconChoice('Material', 'chat', 'Chat', Icons.chat),
    const NavIconChoice('Material', 'chat_bubble_outline', 'Chat Bubble', Icons.chat_bubble_outline),
    const NavIconChoice('Material', 'forum', 'Forum', Icons.forum),
    const NavIconChoice('Material', 'email', 'Email', Icons.email),
    const NavIconChoice('Material', 'call', 'Call', Icons.call),
    const NavIconChoice('Material', 'video_call', 'Video Call', Icons.video_call),
    const NavIconChoice('Material', 'photo_camera', 'Camera', Icons.photo_camera),
    const NavIconChoice('Material', 'image', 'Image', Icons.image),
    const NavIconChoice('Material', 'movie', 'Video', Icons.movie),
    const NavIconChoice('Material', 'music_note', 'Music', Icons.music_note),
    const NavIconChoice('Material', 'play_circle_outline', 'Play', Icons.play_circle_outline),
    const NavIconChoice('Material', 'podcasts', 'Podcasts', Icons.podcasts),
    const NavIconChoice('Material', 'newspaper', 'News', Icons.newspaper),
    const NavIconChoice('Material', 'rss_feed', 'RSS Feed', Icons.rss_feed),
    // Buildings and places
    const NavIconChoice('Material', 'apartment', 'Apartment', Icons.apartment),
    const NavIconChoice('Material', 'business', 'Business', Icons.business),
    const NavIconChoice('Material', 'business_center', 'Business Center', Icons.business_center),
    const NavIconChoice('Material', 'account_balance', 'Bank', Icons.account_balance),
    const NavIconChoice('Material', 'home_work', 'Home / Office', Icons.home_work),
    const NavIconChoice('Material', 'location_city', 'City', Icons.location_city),
    const NavIconChoice('Material', 'hotel', 'Hotel', Icons.hotel),
    const NavIconChoice('Material', 'restaurant', 'Restaurant', Icons.restaurant),
    const NavIconChoice('Material', 'local_cafe', 'Cafe', Icons.local_cafe),
    const NavIconChoice('Material', 'school', 'School', Icons.school),
    const NavIconChoice('Material', 'local_hospital', 'Hospital', Icons.local_hospital),
    const NavIconChoice('Material', 'church', 'Church', Icons.church),
    const NavIconChoice('Material', 'factory', 'Factory', Icons.factory),
    const NavIconChoice('Material', 'warehouse', 'Warehouse', Icons.warehouse),
    const NavIconChoice('Material', 'location_on', 'Location', Icons.location_on),
    const NavIconChoice('Material', 'map', 'Map', Icons.map),
    const NavIconChoice('Material', 'public', 'World', Icons.public),
    const NavIconChoice('Material', 'language', 'Language', Icons.language),
    // Digital, internet and security
    const NavIconChoice('Material', 'wifi', 'Wi-Fi', Icons.wifi),
    const NavIconChoice('Material', 'router', 'Router', Icons.router),
    const NavIconChoice('Material', 'devices', 'Devices', Icons.devices),
    const NavIconChoice('Material', 'smartphone', 'Smartphone', Icons.smartphone),
    const NavIconChoice('Material', 'computer', 'Computer', Icons.computer),
    const NavIconChoice('Material', 'memory', 'Memory', Icons.memory),
    const NavIconChoice('Material', 'hub', 'Network Hub', Icons.hub),
    const NavIconChoice('Material', 'cloud_upload', 'Cloud Upload', Icons.cloud_upload),
    const NavIconChoice('Material', 'cloud_download', 'Cloud Download', Icons.cloud_download),
    const NavIconChoice('Material', 'database', 'Database', Icons.storage),
    const NavIconChoice('Material', 'code', 'Code', Icons.code),
    const NavIconChoice('Material', 'terminal', 'Terminal', Icons.terminal),
    const NavIconChoice('Material', 'security', 'Security', Icons.security),
    const NavIconChoice('Material', 'lock', 'Lock', Icons.lock),
    const NavIconChoice('Material', 'vpn_key', 'Access Key', Icons.vpn_key),
    const NavIconChoice('Material', 'verified', 'Verified', Icons.verified),
    const NavIconChoice('Material', 'support_agent', 'Support Agent', Icons.support_agent),
    const NavIconChoice('Material', 'analytics', 'Analytics', Icons.analytics),
    const NavIconChoice('Material', 'bar_chart', 'Bar Chart', Icons.bar_chart),
    const NavIconChoice('Material', 'pie_chart', 'Pie Chart', Icons.pie_chart),
    const NavIconChoice('Material', 'dashboard', 'Dashboard', Icons.dashboard),
    const NavIconChoice('Material', 'settings', 'Settings', Icons.settings),
    const NavIconChoice('Material', 'notifications', 'Notifications Filled', Icons.notifications),
    const NavIconChoice('Material', 'help', 'Help', Icons.help),
    const NavIconChoice('Material', 'info', 'Information', Icons.info),
    const NavIconChoice('Material', 'star', 'Star', Icons.star),
    const NavIconChoice('Material', 'trending_up', 'Trending Up', Icons.trending_up),
    const NavIconChoice('Material', 'calendar_today', 'Calendar Today', Icons.calendar_today),
    const NavIconChoice('Material', 'event', 'Event', Icons.event),
    const NavIconChoice('Material', 'history', 'History', Icons.history),
    const NavIconChoice('Material', 'schedule', 'Schedule', Icons.schedule),
    const NavIconChoice('Material', 'timer', 'Timer', Icons.timer),
    const NavIconChoice('Material', 'bookmark', 'Bookmark', Icons.bookmark),
    const NavIconChoice('Material', 'flag', 'Flag', Icons.flag),
    const NavIconChoice('Material', 'work', 'Work', Icons.work),
    const NavIconChoice('Material', 'construction', 'Construction', Icons.construction),
    const NavIconChoice('Material', 'engineering', 'Engineering', Icons.engineering),
    const NavIconChoice('Material', 'fitness_center', 'Fitness', Icons.fitness_center),
    const NavIconChoice('Material', 'sports_esports', 'Gaming', Icons.sports_esports),
    const NavIconChoice('Material', 'health_and_safety', 'Health & Safety', Icons.health_and_safety),
    const NavIconChoice('Material', 'medical_services', 'Medical Services', Icons.medical_services),
    const NavIconChoice('Material', 'science', 'Science', Icons.science),
    const NavIconChoice('Material', 'solar_power', 'Solar Power', Icons.solar_power),
    const NavIconChoice('Material', 'battery_charging_full', 'Battery', Icons.battery_charging_full),
    const NavIconChoice('Cupertino', 'house', 'House', CupertinoIcons.house),
    const NavIconChoice('Cupertino', 'house_fill', 'House Filled', CupertinoIcons.house_fill),
    const NavIconChoice('Cupertino', 'square_grid_2x2', 'Grid', CupertinoIcons.square_grid_2x2),
    const NavIconChoice('Cupertino', 'heart', 'Heart', CupertinoIcons.heart),
    const NavIconChoice('Cupertino', 'heart_fill', 'Heart Filled', CupertinoIcons.heart_fill),
    const NavIconChoice('Cupertino', 'bag', 'Bag', CupertinoIcons.bag),
    const NavIconChoice('Cupertino', 'cart', 'Cart', CupertinoIcons.cart),
    const NavIconChoice('Cupertino', 'person', 'Person', CupertinoIcons.person),
    const NavIconChoice('Cupertino', 'person_fill', 'Person Filled', CupertinoIcons.person_fill),
    const NavIconChoice('Cupertino', 'search', 'Search', CupertinoIcons.search),
    const NavIconChoice('Cupertino', 'calendar', 'Calendar', CupertinoIcons.calendar),
    const NavIconChoice('Cupertino', 'doc_text', 'Document', CupertinoIcons.doc_text),
    const NavIconChoice('Cupertino', 'list_bullet', 'List', CupertinoIcons.list_bullet),
    const NavIconChoice('Cupertino', 'plus', 'Add', CupertinoIcons.plus),
    NavIconChoice('Font Awesome', 'house', 'House', FontAwesomeIcons.house),
    NavIconChoice('Font Awesome', 'houseSolid', 'House Solid', FontAwesomeIcons.house),
    NavIconChoice('Font Awesome', 'heart', 'Heart', FontAwesomeIcons.heart),
    NavIconChoice('Font Awesome', 'cartShopping', 'Cart', FontAwesomeIcons.cartShopping),
    NavIconChoice('Font Awesome', 'bagShopping', 'Bag', FontAwesomeIcons.bagShopping),
    NavIconChoice('Font Awesome', 'user', 'User', FontAwesomeIcons.user),
    NavIconChoice('Font Awesome', 'magnifyingGlass', 'Search', FontAwesomeIcons.magnifyingGlass),
    NavIconChoice('Font Awesome', 'calendar', 'Calendar', FontAwesomeIcons.calendar),
    NavIconChoice('Font Awesome', 'clipboardList', 'Orders', FontAwesomeIcons.clipboardList),
    NavIconChoice('Font Awesome', 'store', 'Store', FontAwesomeIcons.store),
    NavIconChoice('Font Awesome', 'fileLines', 'Posts', FontAwesomeIcons.fileLines),
    NavIconChoice('Font Awesome', 'bell', 'Bell', FontAwesomeIcons.bell),
    NavIconChoice('Font Awesome', 'plus', 'Add', FontAwesomeIcons.plus),
    NavIconChoice('Font Awesome', 'userCircle', 'User Circle', FontAwesomeIcons.circleUser),

    NavIconChoice('Font Awesome', 'instagram', 'Instagram', FontAwesomeIcons.instagram),
    NavIconChoice('Font Awesome', 'facebook', 'Facebook', FontAwesomeIcons.facebook),
    NavIconChoice('Font Awesome', 'whatsapp', 'WhatsApp', FontAwesomeIcons.whatsapp),
    NavIconChoice('Font Awesome', 'youtube', 'YouTube', FontAwesomeIcons.youtube),
    NavIconChoice('Font Awesome', 'telegram', 'Telegram', FontAwesomeIcons.telegram),
    NavIconChoice('Font Awesome', 'linkedin', 'LinkedIn', FontAwesomeIcons.linkedin),
    NavIconChoice('Font Awesome', 'pinterest', 'Pinterest', FontAwesomeIcons.pinterest),
    NavIconChoice('Font Awesome', 'reddit', 'Reddit', FontAwesomeIcons.reddit),
    NavIconChoice('Font Awesome', 'snapchat', 'Snapchat', FontAwesomeIcons.snapchat),
    NavIconChoice('Font Awesome', 'discord', 'Discord', FontAwesomeIcons.discord),
    NavIconChoice('Font Awesome', 'github', 'GitHub', FontAwesomeIcons.github),
    NavIconChoice('Font Awesome', 'tiktok', 'TikTok', FontAwesomeIcons.tiktok),
    const NavIconChoice('Remix Icons', 'home_3_line', 'Home Outline', RemixIcons.home_3_line),
    const NavIconChoice('Remix Icons', 'home_3_fill', 'Home Filled', RemixIcons.home_3_fill),
    const NavIconChoice('Remix Icons', 'apps_2_line', 'Apps', RemixIcons.apps_2_line),
    const NavIconChoice('Remix Icons', 'heart_line', 'Heart', RemixIcons.heart_line),
    const NavIconChoice('Remix Icons', 'heart_fill', 'Heart Filled', RemixIcons.heart_fill),
    const NavIconChoice('Remix Icons', 'shopping_cart_line', 'Cart', RemixIcons.shopping_cart_line),
    const NavIconChoice('Remix Icons', 'shopping_bag_line', 'Bag', RemixIcons.shopping_bag_line),
    const NavIconChoice('Remix Icons', 'user_3_line', 'User', RemixIcons.user_3_line),
    const NavIconChoice('Remix Icons', 'user_3_fill', 'User Filled', RemixIcons.user_3_fill),
    const NavIconChoice('Remix Icons', 'search_line', 'Search', RemixIcons.search_line),
    const NavIconChoice('Remix Icons', 'calendar_line', 'Calendar', RemixIcons.calendar_line),
    const NavIconChoice('Remix Icons', 'file_list_3_line', 'Orders', RemixIcons.file_list_3_line),
    const NavIconChoice('Remix Icons', 'store_2_line', 'Store', RemixIcons.store_2_line),
    const NavIconChoice('Remix Icons', 'add_line', 'Add', RemixIcons.add_line),
    const NavIconChoice('FluentUI', 'home_24_regular', 'Home', FluentIcons.home_24_regular),
    const NavIconChoice('FluentUI', 'home_24_filled', 'Home Filled', FluentIcons.home_24_filled),
    const NavIconChoice('FluentUI', 'grid_24_regular', 'Grid', FluentIcons.grid_24_regular),
    const NavIconChoice('FluentUI', 'heart_24_regular', 'Heart', FluentIcons.heart_24_regular),
    const NavIconChoice('FluentUI', 'heart_24_filled', 'Heart Filled', FluentIcons.heart_24_filled),
    const NavIconChoice('FluentUI', 'cart_24_regular', 'Cart', FluentIcons.cart_24_regular),
    const NavIconChoice('FluentUI', 'person_24_regular', 'Person', FluentIcons.person_24_regular),
    const NavIconChoice('FluentUI', 'person_24_filled', 'Person Filled', FluentIcons.person_24_filled),
    const NavIconChoice('FluentUI', 'search_24_regular', 'Search', FluentIcons.search_24_regular),
    const NavIconChoice('FluentUI', 'calendar_24_regular', 'Calendar', FluentIcons.calendar_24_regular),
    const NavIconChoice('FluentUI', 'receipt_24_regular', 'Orders', FluentIcons.receipt_24_regular),
    const NavIconChoice('FluentUI', 'store_microsoft_24_regular', 'Store', FluentIcons.store_microsoft_24_regular),
    const NavIconChoice('FluentUI', 'document_24_regular', 'Posts', FluentIcons.document_24_regular),
    const NavIconChoice('FluentUI', 'apps_24_regular', 'Apps', FluentIcons.apps_24_regular),
    const NavIconChoice('FluentUI', 'add_24_regular', 'Add', FluentIcons.add_24_regular),
  ]..addAll(_additionalMaterialIcons);

  static const List<NavIconChoice> _additionalMaterialIcons = [
    const NavIconChoice('Material', 'account_box', 'Account Box', Icons.account_box),
    const NavIconChoice('Material', 'account_tree', 'Account Tree', Icons.account_tree),
    const NavIconChoice('Material', 'add_a_photo', 'Add A Photo', Icons.add_a_photo),
    const NavIconChoice('Material', 'add_alert', 'Add Alert', Icons.add_alert),
    const NavIconChoice('Material', 'add_business', 'Add Business', Icons.add_business),
    const NavIconChoice('Material', 'add_card', 'Add Card', Icons.add_card),
    const NavIconChoice('Material', 'add_chart', 'Add Chart', Icons.add_chart),
    const NavIconChoice('Material', 'add_circle_outline', 'Add Circle Outline', Icons.add_circle_outline),
    const NavIconChoice('Material', 'add_home', 'Add Home', Icons.add_home),
    const NavIconChoice('Material', 'add_location', 'Add Location', Icons.add_location),
    const NavIconChoice('Material', 'add_moderator', 'Add Moderator', Icons.add_moderator),
    const NavIconChoice('Material', 'add_shopping_cart', 'Add Shopping Cart', Icons.add_shopping_cart),
    const NavIconChoice('Material', 'add_task', 'Add Task', Icons.add_task),
    const NavIconChoice('Material', 'admin_panel_settings', 'Admin Panel Settings', Icons.admin_panel_settings),
    const NavIconChoice('Material', 'ads_click', 'Ads Click', Icons.ads_click),
    const NavIconChoice('Material', 'airline_seat_recline_normal', 'Airline Seat Recline Normal', Icons.airline_seat_recline_normal),
    const NavIconChoice('Material', 'alarm_add', 'Alarm Add', Icons.alarm_add),
    const NavIconChoice('Material', 'album', 'Album', Icons.album),
    const NavIconChoice('Material', 'all_inbox', 'All Inbox', Icons.all_inbox),
    const NavIconChoice('Material', 'anchor', 'Anchor', Icons.anchor),
    const NavIconChoice('Material', 'android', 'Android', Icons.android),
    const NavIconChoice('Material', 'announcement', 'Announcement', Icons.announcement),
    const NavIconChoice('Material', 'api', 'Api', Icons.api),
    const NavIconChoice('Material', 'app_registration', 'App Registration', Icons.app_registration),
    const NavIconChoice('Material', 'archive', 'Archive', Icons.archive),
    const NavIconChoice('Material', 'arrow_circle_down', 'Arrow Circle Down', Icons.arrow_circle_down),
    const NavIconChoice('Material', 'arrow_circle_up', 'Arrow Circle Up', Icons.arrow_circle_up),
    const NavIconChoice('Material', 'arrow_downward', 'Arrow Downward', Icons.arrow_downward),
    const NavIconChoice('Material', 'arrow_upward', 'Arrow Upward', Icons.arrow_upward),
    const NavIconChoice('Material', 'assignment', 'Assignment', Icons.assignment),
    const NavIconChoice('Material', 'assignment_ind', 'Assignment Ind', Icons.assignment_ind),
    const NavIconChoice('Material', 'assignment_turned_in', 'Assignment Turned In', Icons.assignment_turned_in),
    const NavIconChoice('Material', 'attach_money', 'Attach Money', Icons.attach_money),
    const NavIconChoice('Material', 'auto_awesome', 'Auto Awesome', Icons.auto_awesome),
    const NavIconChoice('Material', 'auto_fix_high', 'Auto Fix High', Icons.auto_fix_high),
    const NavIconChoice('Material', 'auto_graph', 'Auto Graph', Icons.auto_graph),
    const NavIconChoice('Material', 'auto_stories', 'Auto Stories', Icons.auto_stories),
    const NavIconChoice('Material', 'backup', 'Backup', Icons.backup),
    const NavIconChoice('Material', 'balance', 'Balance', Icons.balance),
    const NavIconChoice('Material', 'battery_0_bar', 'Battery 0 Bar', Icons.battery_0_bar),
    const NavIconChoice('Material', 'battery_4_bar', 'Battery 4 Bar', Icons.battery_4_bar),
    const NavIconChoice('Material', 'beenhere', 'Beenhere', Icons.beenhere),
    const NavIconChoice('Material', 'bento', 'Bento', Icons.bento),
    const NavIconChoice('Material', 'blender', 'Blender', Icons.blender),
    const NavIconChoice('Material', 'blind', 'Blind', Icons.blind),
    const NavIconChoice('Material', 'bloodtype', 'Bloodtype', Icons.bloodtype),
    const NavIconChoice('Material', 'bluetooth_audio', 'Bluetooth Audio', Icons.bluetooth_audio),
    const NavIconChoice('Material', 'bluetooth_connected', 'Bluetooth Connected', Icons.bluetooth_connected),
    const NavIconChoice('Material', 'bluetooth_disabled', 'Bluetooth Disabled', Icons.bluetooth_disabled),
    const NavIconChoice('Material', 'bluetooth_searching', 'Bluetooth Searching', Icons.bluetooth_searching),
    const NavIconChoice('Material', 'blur_circular', 'Blur Circular', Icons.blur_circular),
    const NavIconChoice('Material', 'blur_linear', 'Blur Linear', Icons.blur_linear),
    const NavIconChoice('Material', 'book_online', 'Book Online', Icons.book_online),
    const NavIconChoice('Material', 'bookmark_add', 'Bookmark Add', Icons.bookmark_add),
    const NavIconChoice('Material', 'bookmark_added', 'Bookmark Added', Icons.bookmark_added),
    const NavIconChoice('Material', 'bookmark_remove', 'Bookmark Remove', Icons.bookmark_remove),
    const NavIconChoice('Material', 'bookmarks', 'Bookmarks', Icons.bookmarks),
    const NavIconChoice('Material', 'border_all', 'Border All', Icons.border_all),
    const NavIconChoice('Material', 'border_color', 'Border Color', Icons.border_color),
    const NavIconChoice('Material', 'branding_watermark', 'Branding Watermark', Icons.branding_watermark),
    const NavIconChoice('Material', 'breakfast_dining', 'Breakfast Dining', Icons.breakfast_dining),
    const NavIconChoice('Material', 'broadcast_on_home', 'Broadcast On Home', Icons.broadcast_on_home),
    const NavIconChoice('Material', 'brunch_dining', 'Brunch Dining', Icons.brunch_dining),
    const NavIconChoice('Material', 'bubble_chart', 'Bubble Chart', Icons.bubble_chart),
    const NavIconChoice('Material', 'bug_report', 'Bug Report', Icons.bug_report),
    const NavIconChoice('Material', 'build_circle', 'Build Circle', Icons.build_circle),
    const NavIconChoice('Material', 'cabin', 'Cabin', Icons.cabin),
    const NavIconChoice('Material', 'calculate', 'Calculate', Icons.calculate),
    const NavIconChoice('Material', 'call_end', 'Call End', Icons.call_end),
    const NavIconChoice('Material', 'call_made', 'Call Made', Icons.call_made),
    const NavIconChoice('Material', 'call_received', 'Call Received', Icons.call_received),
    const NavIconChoice('Material', 'camera_enhance', 'Camera Enhance', Icons.camera_enhance),
    const NavIconChoice('Material', 'camera_front', 'Camera Front', Icons.camera_front),
    const NavIconChoice('Material', 'camera_rear', 'Camera Rear', Icons.camera_rear),
    const NavIconChoice('Material', 'campaign', 'Campaign', Icons.campaign),
    const NavIconChoice('Material', 'car_rental', 'Car Rental', Icons.car_rental),
    const NavIconChoice('Material', 'car_repair', 'Car Repair', Icons.car_repair),
    const NavIconChoice('Material', 'carpenter', 'Carpenter', Icons.carpenter),
    const NavIconChoice('Material', 'cases', 'Cases', Icons.cases),
    const NavIconChoice('Material', 'cast', 'Cast', Icons.cast),
    const NavIconChoice('Material', 'cast_connected', 'Cast Connected', Icons.cast_connected),
    const NavIconChoice('Material', 'cast_for_education', 'Cast For Education', Icons.cast_for_education),
    const NavIconChoice('Material', 'category', 'Category', Icons.category),
    const NavIconChoice('Material', 'celebration', 'Celebration', Icons.celebration),
    const NavIconChoice('Material', 'check_circle', 'Check Circle', Icons.check_circle),
    const NavIconChoice('Material', 'checkroom', 'Checkroom', Icons.checkroom),
    const NavIconChoice('Material', 'child_care', 'Child Care', Icons.child_care),
    const NavIconChoice('Material', 'child_friendly', 'Child Friendly', Icons.child_friendly),
    const NavIconChoice('Material', 'chrome_reader_mode', 'Chrome Reader Mode', Icons.chrome_reader_mode),
    const NavIconChoice('Material', 'circle_notifications', 'Circle Notifications', Icons.circle_notifications),
    const NavIconChoice('Material', 'cleaning_services', 'Cleaning Services', Icons.cleaning_services),
    const NavIconChoice('Material', 'clear_all', 'Clear All', Icons.clear_all),
    const NavIconChoice('Material', 'close_fullscreen', 'Close Fullscreen', Icons.close_fullscreen),
    const NavIconChoice('Material', 'cloud_circle', 'Cloud Circle', Icons.cloud_circle),
    const NavIconChoice('Material', 'cloud_done', 'Cloud Done', Icons.cloud_done),
    const NavIconChoice('Material', 'cloud_off', 'Cloud Off', Icons.cloud_off),
    const NavIconChoice('Material', 'cloud_sync', 'Cloud Sync', Icons.cloud_sync),
    const NavIconChoice('Material', 'co2', 'Co2', Icons.co2),
    const NavIconChoice('Material', 'code_off', 'Code Off', Icons.code_off),
    const NavIconChoice('Material', 'collections_bookmark', 'Collections Bookmark', Icons.collections_bookmark),
    const NavIconChoice('Material', 'color_lens', 'Color Lens', Icons.color_lens),
    const NavIconChoice('Material', 'colorize', 'Colorize', Icons.colorize),
    const NavIconChoice('Material', 'comment', 'Comment', Icons.comment),
    const NavIconChoice('Material', 'compare', 'Compare', Icons.compare),
    const NavIconChoice('Material', 'confirmation_num', 'Confirmation Num', Icons.confirmation_num),
    const NavIconChoice('Material', 'contact_mail', 'Contact Mail', Icons.contact_mail),
    const NavIconChoice('Material', 'contact_phone', 'Contact Phone', Icons.contact_phone),
    const NavIconChoice('Material', 'contactless', 'Contactless', Icons.contactless),
    const NavIconChoice('Material', 'content_copy', 'Content Copy', Icons.content_copy),
    const NavIconChoice('Material', 'content_cut', 'Content Cut', Icons.content_cut),
    const NavIconChoice('Material', 'content_paste', 'Content Paste', Icons.content_paste),
    const NavIconChoice('Material', 'contrast', 'Contrast', Icons.contrast),
    const NavIconChoice('Material', 'control_camera', 'Control Camera', Icons.control_camera),
    const NavIconChoice('Material', 'cookie', 'Cookie', Icons.cookie),
    const NavIconChoice('Material', 'copy_all', 'Copy All', Icons.copy_all),
    const NavIconChoice('Material', 'copyright', 'Copyright', Icons.copyright),
    const NavIconChoice('Material', 'cottage', 'Cottage', Icons.cottage),
    const NavIconChoice('Material', 'currency_bitcoin', 'Currency Bitcoin', Icons.currency_bitcoin),
    const NavIconChoice('Material', 'dashboard_customize', 'Dashboard Customize', Icons.dashboard_customize),
    const NavIconChoice('Material', 'data_array', 'Data Array', Icons.data_array),
    const NavIconChoice('Material', 'data_exploration', 'Data Exploration', Icons.data_exploration),
    const NavIconChoice('Material', 'data_object', 'Data Object', Icons.data_object),
    const NavIconChoice('Material', 'dataset', 'Dataset', Icons.dataset),
    const NavIconChoice('Material', 'density_large', 'Density Large', Icons.density_large),
    const NavIconChoice('Material', 'dns', 'Dns', Icons.dns),
    const NavIconChoice('Material', 'domain', 'Domain', Icons.domain),
    const NavIconChoice('Material', 'done_all', 'Done All', Icons.done_all),
    const NavIconChoice('Material', 'drafts', 'Drafts', Icons.drafts),
    const NavIconChoice('Material', 'drag_indicator', 'Drag Indicator', Icons.drag_indicator),
    const NavIconChoice('Material', 'draw', 'Draw', Icons.draw),
    const NavIconChoice('Material', 'drive_file_move', 'Drive File Move', Icons.drive_file_move),
    const NavIconChoice('Material', 'drive_folder_upload', 'Drive Folder Upload', Icons.drive_folder_upload),
    const NavIconChoice('Material', 'edit_calendar', 'Edit Calendar', Icons.edit_calendar),
    const NavIconChoice('Material', 'electric_moped', 'Electric Moped', Icons.electric_moped),
    const NavIconChoice('Material', 'electric_rickshaw', 'Electric Rickshaw', Icons.electric_rickshaw),
    const NavIconChoice('Material', 'electric_scooter', 'Electric Scooter', Icons.electric_scooter),
    const NavIconChoice('Material', 'emergency', 'Emergency', Icons.emergency),
    const NavIconChoice('Material', 'energy_savings_leaf', 'Energy Savings Leaf', Icons.energy_savings_leaf),
    const NavIconChoice('Material', 'error_outline', 'Error Outline', Icons.error_outline),
    const NavIconChoice('Material', 'escalator', 'Escalator', Icons.escalator),
    const NavIconChoice('Material', 'event_available', 'Event Available', Icons.event_available),
    const NavIconChoice('Material', 'event_busy', 'Event Busy', Icons.event_busy),
    const NavIconChoice('Material', 'expand_circle_down', 'Expand Circle Down', Icons.expand_circle_down),
    const NavIconChoice('Material', 'extension', 'Extension', Icons.extension),
    const NavIconChoice('Material', 'face', 'Face', Icons.face),
    const NavIconChoice('Material', 'family_restroom', 'Family Restroom', Icons.family_restroom),
    const NavIconChoice('Material', 'festival', 'Festival', Icons.festival),
    const NavIconChoice('Material', 'file_copy', 'File Copy', Icons.file_copy),
    const NavIconChoice('Material', 'file_download', 'File Download', Icons.file_download),
    const NavIconChoice('Material', 'file_open', 'File Open', Icons.file_open),
    const NavIconChoice('Material', 'file_present', 'File Present', Icons.file_present),
    const NavIconChoice('Material', 'filter_alt', 'Filter Alt', Icons.filter_alt),
    const NavIconChoice('Material', 'fingerprint', 'Fingerprint', Icons.fingerprint),
    const NavIconChoice('Material', 'fire_extinguisher', 'Fire Extinguisher', Icons.fire_extinguisher),
    const NavIconChoice('Material', 'fire_truck', 'Fire Truck', Icons.fire_truck),
    const NavIconChoice('Material', 'flag_circle', 'Flag Circle', Icons.flag_circle),
    const NavIconChoice('Material', 'flatware', 'Flatware', Icons.flatware),
    const NavIconChoice('Material', 'flight_class', 'Flight Class', Icons.flight_class),
    const NavIconChoice('Material', 'flip_camera_android', 'Flip Camera Android', Icons.flip_camera_android),
    const NavIconChoice('Material', 'folder_copy', 'Folder Copy', Icons.folder_copy),
    const NavIconChoice('Material', 'folder_delete', 'Folder Delete', Icons.folder_delete),
    const NavIconChoice('Material', 'folder_shared', 'Folder Shared', Icons.folder_shared),
    const NavIconChoice('Material', 'follow_the_signs', 'Follow The Signs', Icons.follow_the_signs),
    const NavIconChoice('Material', 'food_bank', 'Food Bank', Icons.food_bank),
    const NavIconChoice('Material', 'format_list_bulleted', 'Format List Bulleted', Icons.format_list_bulleted),
    const NavIconChoice('Material', 'forward_to_inbox', 'Forward To Inbox', Icons.forward_to_inbox),
    const NavIconChoice('Material', 'free_cancellation', 'Free Cancellation', Icons.free_cancellation),
    const NavIconChoice('Material', 'g_translate', 'G Translate', Icons.g_translate),
    const NavIconChoice('Material', 'gavel', 'Gavel', Icons.gavel),
    const NavIconChoice('Material', 'generating_tokens', 'Generating Tokens', Icons.generating_tokens),
    const NavIconChoice('Material', 'grade', 'Grade', Icons.grade),
    const NavIconChoice('Material', 'group_add', 'Group Add', Icons.group_add),
    const NavIconChoice('Material', 'group_work', 'Group Work', Icons.group_work),
    const NavIconChoice('Material', 'handshake', 'Handshake', Icons.handshake),
    const NavIconChoice('Material', 'hardware', 'Hardware', Icons.hardware),
    const NavIconChoice('Material', 'help_center', 'Help Center', Icons.help_center),
    const NavIconChoice('Material', 'hexagon', 'Hexagon', Icons.hexagon),
    const NavIconChoice('Material', 'history_edu', 'History Edu', Icons.history_edu),
    const NavIconChoice('Material', 'home_repair_service', 'Home Repair Service', Icons.home_repair_service),
    const NavIconChoice('Material', 'hourglass_bottom', 'Hourglass Bottom', Icons.hourglass_bottom),
    const NavIconChoice('Material', 'icecream', 'Icecream', Icons.icecream),
    const NavIconChoice('Material', 'image_aspect_ratio', 'Image Aspect Ratio', Icons.image_aspect_ratio),
    const NavIconChoice('Material', 'important_devices', 'Important Devices', Icons.important_devices),
    const NavIconChoice('Material', 'inbox', 'Inbox', Icons.inbox),
    const NavIconChoice('Material', 'indeterminate_check_box', 'Indeterminate Check Box', Icons.indeterminate_check_box),
    const NavIconChoice('Material', 'input', 'Input', Icons.input),
    const NavIconChoice('Material', 'insights', 'Insights', Icons.insights),
    const NavIconChoice('Material', 'javascript', 'Javascript', Icons.javascript),
    const NavIconChoice('Material', 'join_full', 'Join Full', Icons.join_full),
    const NavIconChoice('Material', 'keyboard', 'Keyboard', Icons.keyboard),
    const NavIconChoice('Material', 'kitchen', 'Kitchen', Icons.kitchen),
    const NavIconChoice('Material', 'label', 'Label', Icons.label),
    const NavIconChoice('Material', 'label_important', 'Label Important', Icons.label_important),
    const NavIconChoice('Material', 'leaderboard', 'Leaderboard', Icons.leaderboard),
    const NavIconChoice('Material', 'library_add', 'Library Add', Icons.library_add),
    const NavIconChoice('Material', 'living', 'Living', Icons.living),
    const NavIconChoice('Material', 'local_activity', 'Local Activity', Icons.local_activity),
    const NavIconChoice('Material', 'local_airport', 'Local Airport', Icons.local_airport),
    const NavIconChoice('Material', 'local_atm', 'Local Atm', Icons.local_atm),
    const NavIconChoice('Material', 'local_bar', 'Local Bar', Icons.local_bar),
  ];

  static NavIconChoice? find(String family, String name) {
    for (final choice in all) {
      if (choice.family == family && choice.name == name) return choice;
    }
    return null;
  }

  static Widget icon(String family, String name, {Color? color, double size = 24}) {
    final value = find(family, name)?.data;
    if (value is FaIconData) return FaIcon(value, color: color, size: size);
    if (value is IconData) return Icon(value, color: color, size: size);
    return Icon(Icons.circle_outlined, color: color, size: size);
  }
}

class DesignerNavigationBarPage extends StatefulWidget {
  const DesignerNavigationBarPage({
    super.key,
    required this.initialConfig,
    required this.onSave,
    this.availablePages = const [],
  });
  final DesignerNavigationConfig initialConfig;
  final ValueChanged<DesignerNavigationConfig> onSave;
  final List<Map<String, String>> availablePages;

  @override
  State<DesignerNavigationBarPage> createState() => _DesignerNavigationBarPageState();
}

class _DesignerNavigationBarPageState extends State<DesignerNavigationBarPage> {
  late DesignerNavigationConfig config;
  int selectedIndex = 0;
  bool reordering = false;

  @override
  void initState() {
    super.initState();
    config = widget.initialConfig.clone();
  }

  void _changed() {
    setState(() {});
    widget.onSave(config.clone());
  }

  Future<void> _addItem() async {
    if (config.items.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bottom Navigation supports up to 5 buttons.')),
      );
      return;
    }
    final item = DesignerNavigationItem(
      id: 'nav-${DateTime.now().microsecondsSinceEpoch}',
      label: 'New Button',
      link: 'home',
      iconName: 'apps',
      activeIconName: 'apps',
    );
    config.items.add(item);
    selectedIndex = config.items.length - 1;
    _changed();
    await _editItem(item);
  }

  Future<void> _editItem(DesignerNavigationItem item) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => DesignerNavigationItemPage(
        item: item,
        onSave: (updated) {
          final index = config.items.indexWhere((e) => e.id == item.id);
          if (index >= 0) config.items[index] = updated;
          selectedIndex = index < 0 ? 0 : index;
          _changed();
        },
        availablePages: widget.availablePages,
        onDelete: () {
          if (config.items.length <= 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Keep at least one Navigation Button in the app.')),
            );
            return;
          }
          config.items.removeWhere((e) => e.id == item.id);
          selectedIndex = selectedIndex.clamp(0, config.items.length - 1);
          _changed();
        },
      ),
    ));
  }

  Future<void> _pickBarColor(String field, String current) async {
    final color = await showDialog<String>(
      context: context,
      builder: (_) => _NavigationColorDialog(initial: current),
    );
    if (color == null) return;
    if (field == 'background') config.backgroundColor = color;
    if (field == 'selected') config.selectedColor = color;
    if (field == 'unselected') config.unselectedColor = color;
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final previewItems = config.items;
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: _navPurple, brightness: Brightness.light),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _navText, elevation: 0),
        dividerColor: _navBorder,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: Padding(
          // Keep the add action clear of the fixed Live Preview navigation bar.
          padding: const EdgeInsets.only(bottom: 88),
          child: FloatingActionButton(
            tooltip: 'Add New Navigation Button',
            onPressed: _addItem,
            backgroundColor: _navPurple,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded),
          ),
        ),
        appBar: AppBar(
          title: const Text('Navigation Bar', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: reordering ? 'Done reordering' : 'Reorder',
              icon: Icon(reordering ? Icons.check_rounded : Icons.swap_vert_rounded),
              onPressed: () => setState(() => reordering = !reordering),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                children: [
                  Card(
                    elevation: 0,
                    color: const Color(0xFFFAF9FC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _navBorder)),
                    child: reordering
                        ? ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: true,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex--;
                              final item = config.items.removeAt(oldIndex);
                              config.items.insert(newIndex, item);
                              selectedIndex = newIndex;
                              _changed();
                            },
                            children: config.items.map((item) => ListTile(
                              key: ValueKey(item.id),
                              leading: DesignerNavIcons.icon(item.iconFamily, item.iconName),
                              title: Text(item.label),
                              subtitle: Text(_linkLabel(item.link)),
                              trailing: const Icon(Icons.drag_handle),
                            )).toList(),
                          )
                        : Column(children: [
                            for (var index = 0; index < previewItems.length; index++)
                              InkWell(
                                onTap: () => _editItem(previewItems[index]),
                                child: _navigationRow(previewItems[index], index),
                              ),
                          ]),
                  ),
                  const SizedBox(height: 14),
                  const Text('Navigation Type', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fixed', label: Text('Fixed'), icon: Icon(Icons.horizontal_rule)),
                      ButtonSegment(value: 'shifting', label: Text('Shifting'), icon: Icon(Icons.swap_horiz)),
                    ],
                    selected: {config.type},
                    onSelectionChanged: (value) {
                      config.type = value.first;
                      _changed();
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Bar Appearance', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _settingTile('Background Color', config.backgroundColor, Icons.format_color_fill, () => _pickBarColor('background', config.backgroundColor)),
                  _settingTile('Selected Color', config.selectedColor, Icons.palette_outlined, () => _pickBarColor('selected', config.selectedColor)),
                  _settingTile('Unselected Color', config.unselectedColor, Icons.color_lens_outlined, () => _pickBarColor('unselected', config.unselectedColor)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Labels'),
                    value: config.showLabels,
                    onChanged: (value) { config.showLabels = value; _changed(); },
                  ),
                  const SizedBox(height: 8),

                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              color: const Color(0xFFF7F7F9),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
                    child: Text('Live Preview', style: TextStyle(fontWeight: FontWeight.w800, color: _navText)),
                  ),
                  BottomNavigationBar(
                    currentIndex: previewItems.isEmpty ? 0 : selectedIndex.clamp(0, previewItems.length - 1),
                    onTap: (index) => setState(() => selectedIndex = index),
                    type: config.type == 'shifting' ? BottomNavigationBarType.shifting : BottomNavigationBarType.fixed,
                    backgroundColor: navColorFromHex(config.backgroundColor),
                    selectedItemColor: navColorFromHex(config.selectedColor, fallback: _navPurple),
                    unselectedItemColor: navColorFromHex(config.unselectedColor, fallback: Colors.grey),
                    showSelectedLabels: config.showLabels,
                    showUnselectedLabels: config.showLabels,
                    elevation: config.elevation,
                    items: previewItems.map((item) => BottomNavigationBarItem(
                      icon: DesignerNavIcons.icon(item.iconFamily, item.iconName),
                      activeIcon: DesignerNavIcons.icon(item.activeIconFamily, item.activeIconName),
                      label: item.label,
                      backgroundColor: navColorFromHex(item.activeBackgroundColor),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationRow(DesignerNavigationItem item, int index) => ListTile(
    dense: false,
    leading: DesignerNavIcons.icon(item.iconFamily, item.iconName, color: navColorFromHex(item.iconColor)),
    title: Text(item.label, style: const TextStyle(color: _navText, fontWeight: FontWeight.w600)),
    subtitle: Text(_linkLabel(item.link), style: const TextStyle(color: Colors.black54, fontSize: 12)),
    trailing: reordering ? const Icon(Icons.drag_handle) : const Icon(Icons.chevron_right),
  );

  Widget _settingTile(String title, String value, IconData icon, VoidCallback onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _navPurple),
    title: Text(title),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(color: navColorFromHex(value), shape: BoxShape.circle, border: Border.all(color: _navBorder))),
      const SizedBox(width: 10),
      const Icon(Icons.chevron_right),
    ]),
    onTap: onTap,
  );

  String _linkLabel(String link) => DesignerNavigationItemPage.linkOptions
      .firstWhere((option) => option.value == link, orElse: () => DesignerNavigationItemPage.linkOptions.first)
      .label;
}

class DesignerNavigationItemPage extends StatefulWidget {
  const DesignerNavigationItemPage({
    super.key,
    required this.item,
    required this.onSave,
    required this.onDelete,
    this.availablePages = const [],
  });
  final DesignerNavigationItem item;
  final ValueChanged<DesignerNavigationItem> onSave;
  final VoidCallback onDelete;
  final List<Map<String, String>> availablePages;

  static const linkOptions = <({String value, String label})>[
    (value: 'home', label: 'Home'),
    (value: 'categories', label: 'Categories'),
    (value: 'orders', label: 'Orders'),
    (value: 'bookings', label: 'Bookings'),
    (value: 'wishlist', label: 'Wishlist'),
    (value: 'store', label: 'Store'),
    (value: 'cart', label: 'Cart'),
    (value: 'search', label: 'Search'),
    (value: 'posts', label: 'Posts'),
    (value: 'page', label: 'Page'),
    (value: 'webview', label: 'Page (WebView)'),
    (value: 'contact_form_7', label: 'Contact Form 7'),
  ];

  @override
  State<DesignerNavigationItemPage> createState() => _DesignerNavigationItemPageState();
}

class _DesignerNavigationItemPageState extends State<DesignerNavigationItemPage> {
  late DesignerNavigationItem item;
  late final TextEditingController labelController;
  late final TextEditingController urlController;

  @override
  void initState() {
    super.initState();
    item = DesignerNavigationItem.fromJson(widget.item.toJson());
    labelController = TextEditingController(text: item.label);
    urlController = TextEditingController(text: item.linkValue);
  }

  @override
  void dispose() {
    labelController.dispose();
    urlController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon({required bool active}) async {
    final selected = await Navigator.of(context).push<NavIconChoice>(MaterialPageRoute(
      builder: (_) => _NavigationIconPickerPage(
        initialFamily: active ? item.activeIconFamily : item.iconFamily,
        initialName: active ? item.activeIconName : item.iconName,
      ),
    ));
    if (selected == null) return;
    setState(() {
      if (active) {
        item.activeIconFamily = selected.family;
        item.activeIconName = selected.name;
      } else {
        item.iconFamily = selected.family;
        item.iconName = selected.name;
      }
    });
  }

  Future<void> _pickColor(String field, String current) async {
    final selected = await showDialog<String>(context: context, builder: (_) => _NavigationColorDialog(initial: current));
    if (selected == null) return;
    setState(() {
      switch (field) {
        case 'icon': item.iconColor = selected; break;
        case 'active': item.activeIconColor = selected; break;
        case 'background': item.itemBackgroundColor = selected; break;
        case 'activeBackground': item.activeBackgroundColor = selected; break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final requiresNativePage = item.link == 'page';
    final requiresUrl = const ['webview', 'posts', 'bookings', 'contact_form_7'].contains(item.link);
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _navText, elevation: 0),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Navigation Item'),
          actions: [
            IconButton(
              tooltip: 'Delete Navigation Button',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete navigation button?'),
                    content: Text('Remove "${item.label}" from the bottom navigation?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  widget.onDelete();
                  Navigator.pop(context);
                }
              },
            ),
            IconButton(onPressed: () {
              item.label = labelController.text.trim().isEmpty ? 'Navigation' : labelController.text.trim();
              item.linkValue = urlController.text.trim();
              widget.onSave(item);
              Navigator.pop(context);
            }, icon: const Icon(Icons.check, color: _navPurple), tooltip: 'Save'),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
              onChanged: (value) => item.label = value,
            ),
            const SizedBox(height: 14),
            _editTile('Background Color', item.itemBackgroundColor, Icons.format_color_fill, () => _pickColor('background', item.itemBackgroundColor)),
            _editTile('Icon Color', item.iconColor, Icons.palette_outlined, () => _pickColor('icon', item.iconColor)),
            _editTile('Active Icon Color', item.activeIconColor, Icons.color_lens_outlined, () => _pickColor('active', item.activeIconColor)),
            _editTile('Active Background Color', item.activeBackgroundColor, Icons.color_lens, () => _pickColor('activeBackground', item.activeBackgroundColor)),
            ListTile(
              leading: DesignerNavIcons.icon(item.iconFamily, item.iconName, color: navColorFromHex(item.iconColor)),
              title: const Text('Icon'),
              subtitle: Text('${item.iconFamily} · ${item.iconName}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickIcon(active: false),
            ),
            ListTile(
              leading: DesignerNavIcons.icon(item.activeIconFamily, item.activeIconName, color: navColorFromHex(item.activeIconColor)),
              title: const Text('Active Icon'),
              subtitle: Text('${item.activeIconFamily} · ${item.activeIconName}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickIcon(active: true),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.link, color: _navPurple),
              title: const Text('Link'),
              subtitle: Text(_linkTitle(item.link)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _chooseLink,
            ),
            if (requiresNativePage && widget.availablePages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  value: widget.availablePages.any((page) => page['key'] == urlController.text)
                      ? urlController.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Choose Native Page',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.availablePages.map((page) => DropdownMenuItem<String>(
                    value: page['key'],
                    child: Text(page['title'] ?? page['key'] ?? 'Page'),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => urlController.text = value);
                  },
                ),
              ),
            if (requiresNativePage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Native Page Key',
                    hintText: 'custom_about',
                    helperText: 'Select a published custom page above or enter its key.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            if (requiresUrl)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Page URL',
                    hintText: 'https://pluginstore.shop/your-page/',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8F7FA), borderRadius: BorderRadius.circular(16), border: Border.all(color: _navBorder)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                Column(children: [
                  DesignerNavIcons.icon(item.iconFamily, item.iconName, color: navColorFromHex(item.iconColor), size: 28),
                  Text(item.label, style: const TextStyle(fontSize: 11)),
                ]),
                Column(children: [
                  DesignerNavIcons.icon(item.activeIconFamily, item.activeIconName, color: navColorFromHex(item.activeIconColor), size: 28),
                  const Text('Active', style: TextStyle(fontSize: 11)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editTile(String title, String value, IconData icon, VoidCallback onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _navPurple),
    title: Text(title),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 24, height: 24, decoration: BoxDecoration(color: navColorFromHex(value), shape: BoxShape.circle, border: Border.all(color: _navBorder))),
      const Icon(Icons.chevron_right),
    ]),
    onTap: onTap,
  );

  Future<void> _chooseLink() async {
    final value = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => _NavigationLinkPickerPage(selected: item.link),
    ));
    if (value != null) {
      setState(() {
        if (value != item.link) urlController.clear();
        item.link = value;
      });
    }
  }

  String _linkTitle(String value) => DesignerNavigationItemPage.linkOptions
      .firstWhere((option) => option.value == value, orElse: () => DesignerNavigationItemPage.linkOptions.first)
      .label;
}

class _NavigationLinkPickerPage extends StatefulWidget {
  const _NavigationLinkPickerPage({required this.selected});
  final String selected;
  @override
  State<_NavigationLinkPickerPage> createState() => _NavigationLinkPickerPageState();
}

class _NavigationLinkPickerPageState extends State<_NavigationLinkPickerPage> {
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white, appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _navText, elevation: 0)),
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Link')),
      body: ListView(
        children: DesignerNavigationItemPage.linkOptions.map((option) => RadioListTile<String>(
          value: option.value,
          groupValue: widget.selected,
          title: Text(option.label),
          onChanged: (value) => Navigator.pop(context, value),
        )).toList(),
      ),
    ),
  );
}

class _NavigationIconPickerPage extends StatefulWidget {
  const _NavigationIconPickerPage({required this.initialFamily, required this.initialName});
  final String initialFamily;
  final String initialName;
  @override
  State<_NavigationIconPickerPage> createState() => _NavigationIconPickerPageState();
}

class _NavigationIconPickerPageState extends State<_NavigationIconPickerPage> {
  late String family = 'All';
  String category = 'All';
  final search = TextEditingController();

  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final query = search.text.toLowerCase().trim();
    final choices = DesignerNavIcons.all.where((choice) {
      final familyMatches = family == 'All' || choice.family == family;
      final categoryMatches = category == 'All' || DesignerNavIcons.categoryFor(choice) == category;
      final queryMatches = query.isEmpty ||
          choice.label.toLowerCase().contains(query) ||
          choice.name.toLowerCase().contains(query) ||
          choice.family.toLowerCase().contains(query);
      return familyMatches && categoryMatches && queryMatches;
    }).toList();
    return Theme(
      data: ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white, appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _navText, elevation: 0)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Icons')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search 200+ icons',
                filled: true,
                fillColor: const Color(0xFFF4F2F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: DesignerNavIcons.categories.map((name) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(name),
                  selected: category == name,
                  onSelected: (_) => setState(() => category = name),
                ),
              )).toList(),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: ['All', ...DesignerNavIcons.families].map((name) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(name),
                  selected: family == name,
                  onSelected: (_) => setState(() => family = name),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: choices.isEmpty
                ? const Center(child: Text('No icons found. Try another category or search.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: choices.length,
                    itemBuilder: (_, index) {
                      final choice = choices[index];
                      final selected = choice.family == widget.initialFamily && choice.name == widget.initialName;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, choice),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFEDE7F8) : const Color(0xFFFAF9FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? _navPurple : _navBorder),
                          ),
                          child: Tooltip(
                            message: '${choice.label} • ${choice.family}',
                            child: DesignerNavIcons.icon(choice.family, choice.name, color: _navText, size: 25),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _NavigationColorDialog extends StatefulWidget {
  const _NavigationColorDialog({required this.initial});
  final String initial;
  @override
  State<_NavigationColorDialog> createState() => _NavigationColorDialogState();
}

class _NavigationColorDialogState extends State<_NavigationColorDialog> {
  late final TextEditingController controller = TextEditingController(text: widget.initial);
  static const colors = [
    '#FFFFFF', '#F7F7F7', '#111111', '#5B3A9E', '#7650B8',
    '#1976D2', '#00897B', '#43A047', '#FFA000', '#E53935',
    '#3949AB', '#8E24AA', '#546E7A', '#241D33', '#EDE7F8',
    '#E3F2FD', '#E8F5E9', '#FFF3E0', '#FCE4EC', '#F3E5F5',
  ];

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Select Color'),
    content: SizedBox(
      width: 320,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 10, runSpacing: 10, children: colors.map((hex) => InkWell(
          onTap: () => setState(() => controller.text = hex),
          child: Container(width: 34, height: 34, decoration: BoxDecoration(color: navColorFromHex(hex), shape: BoxShape.circle, border: Border.all(color: _navBorder, width: 1.2))),
        )).toList()),
        const SizedBox(height: 14),
        TextField(controller: controller, decoration: const InputDecoration(labelText: 'HEX Color', hintText: '#FFFFFF', border: OutlineInputBorder())),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        final value = controller.text.trim();
        if (value.length == 7) Navigator.pop(context, value);
      }, child: const Text('Apply')),
    ],
  );
}

class NavigationWebPage extends StatefulWidget {
  const NavigationWebPage({super.key, required this.title, required this.url});
  final String title;
  final String url;
  @override
  State<NavigationWebPage> createState() => _NavigationWebPageState();
}

class _NavigationWebPageState extends State<NavigationWebPage> {
  late final WebViewController controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) { if (mounted) setState(() { loading = true; error = null; }); },
        onPageFinished: (_) { if (mounted) setState(() => loading = false); },
        onWebResourceError: (e) { if (mounted && e.isForMainFrame == true) setState(() { loading = false; error = e.description; }); },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [
      IconButton(onPressed: () => controller.reload(), icon: const Icon(Icons.refresh)),
    ]),
    body: Stack(children: [
      WebViewWidget(controller: controller),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center))),
    ]),
  );
}
