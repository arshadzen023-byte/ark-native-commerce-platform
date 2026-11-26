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
    const NavIconChoice('Material', 'menu', 'Menu', Icons.menu),
    const NavIconChoice('Material', 'more_horiz', 'More', Icons.more_horiz),

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
    const NavIconChoice('Cupertino', 'line_3_horizontal', 'Menu', CupertinoIcons.line_horizontal_3),
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
    NavIconChoice('Font Awesome', 'bars', 'Menu', FontAwesomeIcons.bars),
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
    const NavIconChoice('Remix Icons', 'menu_line', 'Menu', RemixIcons.menu_line),
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
          padding: const EdgeInsets.only(bottom: 58),
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
              icon: Icon(reordering ? Icons.check_rounded : Icons.reorder_rounded),
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
  late String family = widget.initialFamily;
  final search = TextEditingController();

  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final query = search.text.toLowerCase().trim();
    final choices = DesignerNavIcons.all.where((choice) =>
      choice.family == family &&
      (query.isEmpty || choice.label.toLowerCase().contains(query) || choice.name.toLowerCase().contains(query))
    ).toList();
    return Theme(
      data: ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white, appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: _navText, elevation: 0)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Icons')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search icon',
                filled: true,
                fillColor: const Color(0xFFF4F2F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: DesignerNavIcons.families.map((name) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(label: Text(name), selected: family == name, onSelected: (_) => setState(() => family = name)),
              )).toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
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
                    child: Tooltip(message: choice.label, child: (choice.data is FaIconData ? FaIcon(choice.data as FaIconData, color: _navText, size: 25) : Icon(choice.data as IconData, color: _navText, size: 25))),
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
