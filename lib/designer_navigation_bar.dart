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
  });
  final DesignerNavigationConfig initialConfig;
  final ValueChanged<DesignerNavigationConfig> onSave;

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
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add New Navigation Button',
          onPressed: _addItem,
          backgroundColor: _navPurple,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add_rounded),
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
  const DesignerNavigationItemPage({super.key, required this.item, required this.onSave, required this.onDelete});
  final DesignerNavigationItem item;
  final ValueChanged<DesignerNavigationItem> onSave;
  final VoidCallback onDelete;

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
            if (requiresNativePage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Native Page Key',
                    hintText: 'custom_about',
                    helperText: 'Enter the custom page key created in ARK Designer Pages.',
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
    if (value != null) setState(() => item.link = value);
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
