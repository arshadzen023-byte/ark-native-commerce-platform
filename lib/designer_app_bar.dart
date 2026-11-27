import 'package:flutter/material.dart';
import 'designer_navigation_bar.dart';

const _appBarPurple = Color(0xFF5B3A9E);

class DesignerAppBarConfig {
  DesignerAppBarConfig({Map<String, dynamic>? json}) : _data = _normalize(json ?? const {});

  final Map<String, dynamic> _data;
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_data);
  String get preset => (_data['preset'] ?? 'custom').toString();
  double get height => ((_data['height'] as num?)?.toDouble() ?? 72).clamp(48.0, 160.0).toDouble();
  double get spacing => ((_data['spacing'] as num?)?.toDouble() ?? 8).clamp(0.0, 32.0).toDouble();
  double get radius => ((_data['radius'] as num?)?.toDouble() ?? 12).clamp(0.0, 36.0).toDouble();
  String get position => (_data['position'] ?? 'top').toString();
  String get backgroundColor => (_data['background_color'] ?? '#FFFFFF').toString();
  String get backgroundImageUrl => (_data['background_image_url'] ?? '').toString();
  String get logoUrl => (_data['logo_url'] ?? '').toString();
  bool get enabled => _data['enabled'] != false;
  bool show(String key) => _data[key] != false;
  bool visibleOn(String page) {
    final pages = _data['visible_pages'];
    if (pages is! Map) return true;
    return pages[page] != false;
  }
  List<Map<String, dynamic>> get actions => (_data['actions'] is List ? _data['actions'] as List : const [])
      .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).take(10).toList();

  static Map<String, dynamic> _normalize(Map<String, dynamic> source) {
    final data = <String, dynamic>{...defaults, ...source};
    final visibility = source['visible_pages'];
    final customPages = visibility is Map
        ? visibility.keys.map((e) => e.toString()).where((key) => RegExp(r'^custom_[a-z0-9_]{1,40}
    final rawActions = source['actions'];
    data['actions'] = rawActions is List
        ? rawActions.whereType<Map>().take(10).map((e) => <String, dynamic>{
            'id': (e['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
            'label': (e['label'] ?? 'Action').toString(),
            'icon_family': (e['icon_family'] ?? 'Material').toString(),
            'icon': (e['icon'] ?? 'star_outline').toString(),
            'link_type': (e['link_type'] ?? 'page').toString(),
            'link_value': (e['link_value'] ?? 'home').toString(),
            'visible': e['visible'] != false,
          }).toList()
        : <Map<String, dynamic>>[];
    data['height'] = ((data['height'] as num?)?.toDouble() ?? 72).clamp(48.0, 160.0);
    data['spacing'] = ((data['spacing'] as num?)?.toDouble() ?? 8).clamp(0.0, 32.0);
    data['radius'] = ((data['radius'] as num?)?.toDouble() ?? 12).clamp(0.0, 36.0);
    data['position'] = ['top', 'floating', 'overlay'].contains(data['position']) ? data['position'] : 'top';
    return data;
  }

  static const pageKeys = ['home','search','categories','wishlist','product','account','cart','orders','notifications'];
  static const defaults = <String, dynamic>{
    'version': 1, 'enabled': true, 'preset': 'custom',
    'background_color': '#FFFFFF', 'foreground_color': '#202124', 'background_image_url': '', 'background_mime_type': '', 'logo_url': '',
    'height': 72.0, 'spacing': 8.0, 'radius': 12.0, 'position': 'top',
    'show_menu': true, 'show_logo': true, 'show_cart': true, 'show_voice_search': true,
    'show_search': true, 'show_wishlist': true, 'show_refresh': false, 'show_location': false,
    'search_placeholder': 'Search products...',
    'menu_icon_family': 'Material', 'menu_icon': 'menu',
    'cart_icon_family': 'Material', 'cart_icon': 'shopping_cart_outlined',
    'voice_icon_family': 'Material', 'voice_icon': 'mic_none',
    'search_icon_family': 'Material', 'search_icon': 'search',
    'wishlist_icon_family': 'Material', 'wishlist_icon': 'favorite_border',
    'refresh_icon_family': 'Material', 'refresh_icon': 'refresh',
    'location_icon_family': 'Material', 'location_icon': 'location_on_outlined',
    'visible_pages': <String, dynamic>{},
    'actions': <dynamic>[],
  };

  static const presets = <Map<String, dynamic>>[
    {'id':'amazon','name':'Amazon','background_color':'#FFD814','foreground_color':'#111111','height':82.0,'radius':8.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':false,'show_location':true},
    {'id':'flipkart','name':'Flipkart','background_color':'#2874F0','foreground_color':'#FFFFFF','height':78.0,'radius':12.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'myntra','name':'Myntra','background_color':'#FFFFFF','foreground_color':'#282C3F','height':70.0,'radius':6.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':true,'show_location':false},
    {'id':'meesho','name':'Meesho','background_color':'#FCEAF3','foreground_color':'#7A174D','height':76.0,'radius':18.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'minimal','name':'Minimal','background_color':'#FFFFFF','foreground_color':'#202124','height':60.0,'radius':0.0,'position':'top','show_menu':false,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':false,'show_location':false},
    {'id':'premium','name':'Premium Dark','background_color':'#171923','foreground_color':'#FFFFFF','height':76.0,'radius':16.0,'position':'floating','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'location','name':'Location First','background_color':'#F0EAFE','foreground_color':'#35235F','height':96.0,'radius':14.0,'position':'top','show_menu':false,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':false,'show_location':true},
    {'id':'gradient','name':'Gradient','background_color':'#5B3A9E','foreground_color':'#FFFFFF','height':78.0,'radius':20.0,'position':'floating','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'compact','name':'Compact','background_color':'#FFFFFF','foreground_color':'#202124','height':52.0,'radius':4.0,'position':'top','show_menu':true,'show_logo':false,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':false,'show_location':false},
    {'id':'search','name':'Search Focus','background_color':'#F7F7F7','foreground_color':'#252525','height':68.0,'radius':24.0,'position':'floating','show_menu':false,'show_logo':false,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':false,'show_location':false},
    {'id':'fashion','name':'Fashion','background_color':'#FBE5E8','foreground_color':'#7A1F35','height':80.0,'radius':10.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':true,'show_location':false},
    {'id':'custom','name':'Custom','background_color':'#FFFFFF','foreground_color':'#24212B','height':72.0,'radius':12.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
  ];

  static Color color(String value, {Color fallback = Colors.white}) {
    final raw = value.replaceFirst('#', '');
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return fallback;
    return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}

class DesignerAppBarBuilderPage extends StatefulWidget {
  const DesignerAppBarBuilderPage({
    super.key,
    required this.initialConfig,
    required this.availablePages,
    required this.onUpload,
    required this.onSave,
  });
  final DesignerAppBarConfig initialConfig;
  final List<Map<String, String>> availablePages;
  final Future<Map<String, dynamic>?> Function() onUpload;
  final ValueChanged<DesignerAppBarConfig> onSave;

  @override
  State<DesignerAppBarBuilderPage> createState() => _DesignerAppBarBuilderPageState();
}

class _DesignerAppBarBuilderPageState extends State<DesignerAppBarBuilderPage> {
  late Map<String, dynamic> data;
  final _color = TextEditingController();
  final _placeholder = TextEditingController();
  final _previewSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    data = widget.initialConfig.toJson();
    final visibility = Map<String, dynamic>.from(data['visible_pages'] as Map? ?? {});
    for (final page in widget.availablePages) {
      final key = page['key'] ?? 'home';
      visibility.putIfAbsent(key, () => true);
    }
    data['visible_pages'] = visibility;
    _color.text = (data['background_color'] ?? '#FFFFFF').toString();
    _placeholder.text = (data['search_placeholder'] ?? 'Search products...').toString();
  }

  @override
  void dispose() {
    _color.dispose();
    _placeholder.dispose();
    _previewSearchController.dispose();
    super.dispose();
  }

  void _set(String key, dynamic value) => setState(() => data[key] = value);

  Future<void> _upload(String target) async {
    final media = await widget.onUpload();
    if (media == null || !mounted) return;
    final url = (media['source_url'] ?? media['url'] ?? '').toString();
    if (url.isEmpty) return;
    setState(() {
      data[target] = url;
      if (target == 'background_image_url') data['background_mime_type'] = (media['mime_type'] ?? '').toString();
    });
  }

  Future<void> _chooseIcon(String key) async {
    final choice = await showDialog<NavIconChoice>(
      context: context,
      builder: (ctx) => const _AppBarIconPickerDialog(),
    );
    if (choice == null || !mounted) return;
    setState(() {
      data['${key}_family'] = choice.family;
      data[key] = choice.name;
    });
  }

  Future<void> _addAction() async {
    final actions = List<Map<String, dynamic>>.from(DesignerAppBarConfig(json: data).actions);
    if (actions.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can add up to 10 custom App Bar actions.')));
      return;
    }
    actions.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'label': 'Action ${actions.length + 1}',
      'icon_family': 'Material',
      'icon': 'star_outline',
      'link_type': 'page',
      'link_value': 'home',
      'visible': true,
    });
    _set('actions', actions);
  }

  Future<void> _editActionIcon(int index) async {
    final choice = await showDialog<NavIconChoice>(context: context, builder: (_) => const _AppBarIconPickerDialog());
    if (choice == null || !mounted) return;
    final actions = DesignerAppBarConfig(json: data).actions;
    actions[index]['icon_family'] = choice.family;
    actions[index]['icon'] = choice.name;
    _set('actions', actions);
  }

  Widget _switch(String key, String label, IconData icon) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    secondary: Icon(icon, color: _appBarPurple),
    title: Text(label),
    value: data[key] != false,
    onChanged: (value) => _set(key, value),
  );

  Widget _presetCard(Map<String, dynamic> preset) {
    final selected = data['preset'] == preset['id'];
    final bg = DesignerAppBarConfig.color(preset['background_color'].toString());
    final fg = DesignerAppBarConfig.color(preset['foreground_color'].toString(), fallback: Colors.black);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        data.addAll(preset);
        data['background_color'] = preset['background_color'];
        data['preset'] = preset['id'];
        _color.text = data['background_color'].toString();
      }),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? _appBarPurple.withOpacity(.10) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _appBarPurple : Theme.of(context).dividerColor, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
            child: Row(children: [
              Icon(Icons.menu, size: 15, color: fg),
              const SizedBox(width: 5),
              Expanded(child: Container(height: 17, decoration: BoxDecoration(color: fg.withOpacity(.12), borderRadius: BorderRadius.circular(12)))),
              Icon(Icons.shopping_cart_outlined, size: 15, color: fg),
            ]),
          ),
          const SizedBox(height: 7),
          Text(preset['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _preview() {
    final config = DesignerAppBarConfig(json: data);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: Colors.black.withOpacity(.04),
          child: const Text('LIVE PREVIEW · GLOWHIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8)),
        ),
        SizedBox(
          height: config.height.clamp(54, 112).toDouble(),
          child: DesignerAppBarView(
            config: config,
            pageKey: 'home',
            cartCount: 2,
            searchController: _previewSearchController,
            onMenu: () {},
            onCart: () {},
            onSearch: () {},
            onVoiceSearch: () {},
            onWishlist: () {},
            onRefresh: () {},
            onLocation: () {},
            onCustomAction: (_) {},
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = DesignerAppBarConfig(json: data);
    return Scaffold(
      appBar: AppBar(title: const Text('App Bar Builder'), actions: [
        TextButton(onPressed: () {
          final normalized = DesignerAppBarConfig(json: data);
          widget.onSave(normalized);
          Navigator.pop(context);
        }, child: const Text('Apply')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _preview(),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('12 Ready-made App Bars', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('${DesignerAppBarConfig.presets.length} designs', style: const TextStyle(color: Colors.grey)),
        ]),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: DesignerAppBarConfig.presets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.15, crossAxisSpacing: 9, mainAxisSpacing: 9),
          itemBuilder: (_, index) => _presetCard(DesignerAppBarConfig.presets[index]),
        ),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Header Controls', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          _switch('enabled', 'Enable App Bar', Icons.visibility_outlined),
          _switch('show_menu', 'Menu button', Icons.menu),
          _switch('show_logo', 'Logo', Icons.image_outlined),
          _switch('show_cart', 'Cart', Icons.shopping_cart_outlined),
          _switch('show_voice_search', 'Voice Search', Icons.mic_none),
          _switch('show_search', 'Search', Icons.search),
          _switch('show_wishlist', 'Wishlist', Icons.favorite_border),
          _switch('show_refresh', 'Refresh', Icons.refresh),
          _switch('show_location', 'Address / Location', Icons.location_on_outlined),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Icon Library', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          for (final item in [
            ('menu_icon', 'Menu Icon', Icons.menu),
            ('cart_icon', 'Cart Icon', Icons.shopping_cart_outlined),
            ('voice_icon', 'Voice Search Icon', Icons.mic_none),
            ('search_icon', 'Search Icon', Icons.search),
            ('wishlist_icon', 'Wishlist Icon', Icons.favorite_border),
            ('refresh_icon', 'Refresh Icon', Icons.refresh),
            ('location_icon', 'Location Icon', Icons.location_on_outlined),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: DesignerNavIcons.icon((data['${item.$1}_family'] ?? 'Material').toString(), (data[item.$1] ?? '').toString(), color: _appBarPurple),
              title: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _chooseIcon(item.$1),
            ),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Logo & Background', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Upload Logo'),
            subtitle: Text(config.logoUrl.isEmpty ? 'No logo selected' : 'Logo uploaded'),
            onTap: () => _upload('logo_url'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wallpaper_outlined),
            title: const Text('Upload Background Image / GIF'),
            subtitle: Text(config.backgroundImageUrl.isEmpty ? 'No background selected' : 'Background media uploaded'),
            onTap: () => _upload('background_image_url'),
          ),
          TextField(controller: _color, decoration: const InputDecoration(labelText: 'Background HEX colour', hintText: '#FFFFFF'), onChanged: (v) => _set('background_color', v)),
          TextField(controller: _placeholder, decoration: const InputDecoration(labelText: 'Search placeholder'), onChanged: (v) => _set('search_placeholder', v)),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dimensions & Position', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          _slider('Header Height', 'height', 48, 160, 1),
          _slider('Icon / Item Spacing', 'spacing', 0, 32, 1),
          _slider('Corner Radius', 'radius', 0, 36, 1),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: config.position,
            decoration: const InputDecoration(labelText: 'Header Position'),
            items: const [
              DropdownMenuItem(value: 'top', child: Text('Top / Standard')),
              DropdownMenuItem(value: 'floating', child: Text('Floating / Rounded')),
              DropdownMenuItem(value: 'overlay', child: Text('Overlay Style')),
            ],
            onChanged: (v) => _set('position', v ?? 'top'),
          ),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Page Visibility', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Text('Choose where this App Bar should appear.'),
          for (final page in widget.availablePages)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(page['title'] ?? page['key'] ?? ''),
              value: (data['visible_pages'] as Map?)?[page['key']] != false,
              onChanged: (v) {
                final map = Map<String, dynamic>.from(data['visible_pages'] as Map? ?? {});
                map[page['key'] ?? 'home'] = v ?? true;
                _set('visible_pages', map);
              },
            ),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Custom Action Buttons', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            TextButton.icon(onPressed: config.actions.length >= 10 ? null : _addAction, icon: const Icon(Icons.add), label: const Text('Add')),
          ]),
          Text('${config.actions.length}/10 actions'),
          for (var i = 0; i < config.actions.length; i++) _actionEditor(i, config.actions[i]),
        ]))),
        const SizedBox(height: 24),
        SizedBox(height: 52, child: FilledButton.icon(
          onPressed: () {
            final normalized = DesignerAppBarConfig(json: data);
            widget.onSave(normalized);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Apply Selected App Bar'),
        )),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _slider(String label, String key, double min, double max, double step) {
    final value = ((data[key] as num?)?.toDouble() ?? min).clamp(min, max).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value.toStringAsFixed(0))]),
      Slider(value: value, min: min, max: max, divisions: ((max - min) / step).round(), onChanged: (v) => _set(key, v)),
    ]);
  }

  Widget _actionEditor(int index, Map<String, dynamic> action) {
    final actions = DesignerAppBarConfig(json: data).actions;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Choose icon',
            onPressed: () => _editActionIcon(index),
            icon: DesignerNavIcons.icon((action['icon_family'] ?? 'Material').toString(), (action['icon'] ?? 'star_outline').toString(), color: _appBarPurple, size: 25),
          ),
          Expanded(child: TextFormField(initialValue: action['label'].toString(), decoration: const InputDecoration(labelText: 'Button label', isDense: true), onChanged: (v) { actions[index]['label'] = v; _set('actions', actions); })),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { actions.removeAt(index); _set('actions', actions); }),
        ]),
        DropdownButtonFormField<String>(
          value: (action['link_type'] ?? 'page').toString(),
          decoration: const InputDecoration(labelText: 'Destination type'),
          items: const [
            DropdownMenuItem(value: 'page', child: Text('App Page')),
            DropdownMenuItem(value: 'url', child: Text('Website URL')),
            DropdownMenuItem(value: 'deep_link', child: Text('App Deep Link')),
          ],
          onChanged: (v) { actions[index]['link_type'] = v ?? 'page'; _set('actions', actions); },
        ),
        TextFormField(initialValue: action['link_value'].toString(), decoration: const InputDecoration(labelText: 'Destination (home / cart / https://...)'), onChanged: (v) { actions[index]['link_value'] = v; _set('actions', actions); }),
      ])),
    );
  }
}

class DesignerAppBarView extends StatelessWidget {
  const DesignerAppBarView({
    super.key,
    required this.config,
    required this.pageKey,
    required this.cartCount,
    required this.searchController,
    required this.onMenu,
    required this.onCart,
    required this.onSearch,
    required this.onVoiceSearch,
    required this.onWishlist,
    required this.onRefresh,
    required this.onLocation,
    required this.onCustomAction,
  });
  final DesignerAppBarConfig config;
  final String pageKey;
  final int cartCount;
  final TextEditingController searchController;
  final VoidCallback onMenu, onCart, onSearch, onVoiceSearch, onWishlist, onRefresh, onLocation;
  final ValueChanged<Map<String, dynamic>> onCustomAction;

  @override
  Widget build(BuildContext context) {
    if (!config.enabled || !config.visibleOn(pageKey)) return const SizedBox.shrink();
    final fg = DesignerAppBarConfig.color((config.toJson()['foreground_color'] ?? '#202124').toString(), fallback: Colors.black);
    final bg = DesignerAppBarConfig.color(config.backgroundColor);
    final data = config.toJson();
    final content = Container(
      height: config.height,
      padding: EdgeInsets.symmetric(horizontal: config.spacing.clamp(0, 24).toDouble()),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(config.position == 'floating' ? config.radius : 0.0),
        image: config.backgroundImageUrl.isEmpty ? null : DecorationImage(
          image: NetworkImage(config.backgroundImageUrl),
          fit: BoxFit.cover,
          onError: (_, __) {},
        ),
        boxShadow: config.position == 'floating' ? [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 3))] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (config.show('show_location'))
          InkWell(onTap: onLocation, child: Row(children: [
            DesignerNavIcons.icon((data['location_icon_family'] ?? 'Material').toString(), (data['location_icon'] ?? 'location_on_outlined').toString(), color: fg, size: 17),
            const SizedBox(width: 4),
            Expanded(child: Text('Deliver to your address', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 11))),
          ])),
        Row(children: [
          if (config.show('show_menu')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMenu,
            icon: DesignerNavIcons.icon((data['menu_icon_family'] ?? 'Material').toString(), (data['menu_icon'] ?? 'menu').toString(), color: fg),
          ),
          if (config.show('show_logo') && config.logoUrl.isNotEmpty)
            Padding(padding: const EdgeInsets.only(right: 7), child: Image.network(config.logoUrl, width: 34, height: 34, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          if (config.show('show_logo') && config.logoUrl.isEmpty)
            Padding(padding: const EdgeInsets.only(right: 7), child: Text('GlowHit', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16))),
          if (config.show('show_search'))
            Expanded(child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(config.radius),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(config.radius)),
                child: Row(children: [
                  DesignerNavIcons.icon((data['search_icon_family'] ?? 'Material').toString(), (data['search_icon'] ?? 'search').toString(), color: Colors.black54, size: 20),
                  const SizedBox(width: 7),
                  Expanded(child: Text(config.toJson()['search_placeholder'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black38, fontSize: 12))),
                ]),
              ),
            ))
          else
            const Spacer(),
          if (config.show('show_voice_search')) IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Voice Search',
            onPressed: onVoiceSearch,
            icon: DesignerNavIcons.icon((data['voice_icon_family'] ?? 'Material').toString(), (data['voice_icon'] ?? 'mic_none').toString(), color: fg),
          ),
          if (config.show('show_wishlist')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onWishlist,
            icon: DesignerNavIcons.icon((data['wishlist_icon_family'] ?? 'Material').toString(), (data['wishlist_icon'] ?? 'favorite_border').toString(), color: fg),
          ),
          if (config.show('show_cart')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onCart,
            icon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: DesignerNavIcons.icon((data['cart_icon_family'] ?? 'Material').toString(), (data['cart_icon'] ?? 'shopping_cart_outlined').toString(), color: fg)),
          ),
          if (config.show('show_refresh')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRefresh,
            icon: DesignerNavIcons.icon((data['refresh_icon_family'] ?? 'Material').toString(), (data['refresh_icon'] ?? 'refresh').toString(), color: fg),
          ),
          for (final action in config.actions.where((a) => a['visible'] != false))
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: (action['label'] ?? 'Action').toString(),
              onPressed: () => onCustomAction(action),
              icon: DesignerNavIcons.icon((action['icon_family'] ?? 'Material').toString(), (action['icon'] ?? 'star_outline').toString(), color: fg, size: 21),
            ),
        ]),
      ]),
    );
    return content;
  }
}

class _AppBarIconPickerDialog extends StatefulWidget {
  const _AppBarIconPickerDialog();
  @override
  State<_AppBarIconPickerDialog> createState() => _AppBarIconPickerDialogState();
}

class _AppBarIconPickerDialogState extends State<_AppBarIconPickerDialog> {
  String query = '';
  String family = 'All';
  @override
  Widget build(BuildContext context) {
    final icons = DesignerNavIcons.all.where((icon) {
      final text = '${icon.name} ${icon.label}'.toLowerCase();
      return (family == 'All' || icon.family == family) && (query.isEmpty || text.contains(query.toLowerCase()));
    }).toList();
    return AlertDialog(
      title: const Text('Choose Icon'),
      content: SizedBox(width: 360, height: 440, child: Column(children: [
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search all icons'), onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: family,
          items: ['All', ...DesignerNavIcons.families].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => family = v ?? 'All'),
        ),
        const SizedBox(height: 8),
        Expanded(child: GridView.builder(
          itemCount: icons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 5, mainAxisSpacing: 5),
          itemBuilder: (_, i) => InkWell(
            onTap: () => Navigator.pop(context, icons[i]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              DesignerNavIcons.icon(icons[i].family, icons[i].name, color: _appBarPurple, size: 24),
              Text(icons[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
            ]),
          ),
        )),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
).hasMatch(key)).toList()
        : <String>[];
    data['visible_pages'] = <String, dynamic>{
      for (final page in [...pageKeys, ...customPages]) page: visibility is Map ? visibility[page] != false : true,
    };
    final rawActions = source['actions'];
    data['actions'] = rawActions is List
        ? rawActions.whereType<Map>().take(10).map((e) => <String, dynamic>{
            'id': (e['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
            'label': (e['label'] ?? 'Action').toString(),
            'icon_family': (e['icon_family'] ?? 'Material').toString(),
            'icon': (e['icon'] ?? 'star_outline').toString(),
            'link_type': (e['link_type'] ?? 'page').toString(),
            'link_value': (e['link_value'] ?? 'home').toString(),
            'visible': e['visible'] != false,
          }).toList()
        : <Map<String, dynamic>>[];
    data['height'] = ((data['height'] as num?)?.toDouble() ?? 72).clamp(48.0, 160.0);
    data['spacing'] = ((data['spacing'] as num?)?.toDouble() ?? 8).clamp(0.0, 32.0);
    data['radius'] = ((data['radius'] as num?)?.toDouble() ?? 12).clamp(0.0, 36.0);
    data['position'] = ['top', 'floating', 'overlay'].contains(data['position']) ? data['position'] : 'top';
    return data;
  }

  static const pageKeys = ['home','search','categories','wishlist','product','account','cart','orders','notifications'];
  static const defaults = <String, dynamic>{
    'version': 1, 'enabled': true, 'preset': 'custom',
    'background_color': '#FFFFFF', 'background_image_url': '', 'logo_url': '',
    'height': 72.0, 'spacing': 8.0, 'radius': 12.0, 'position': 'top',
    'show_menu': true, 'show_logo': true, 'show_cart': true, 'show_voice_search': true,
    'show_search': true, 'show_wishlist': true, 'show_refresh': false, 'show_location': false,
    'search_placeholder': 'Search products...',
    'menu_icon_family': 'Material', 'menu_icon': 'menu',
    'cart_icon_family': 'Material', 'cart_icon': 'shopping_cart_outlined',
    'voice_icon_family': 'Material', 'voice_icon': 'mic_none',
    'search_icon_family': 'Material', 'search_icon': 'search',
    'wishlist_icon_family': 'Material', 'wishlist_icon': 'favorite_border',
    'refresh_icon_family': 'Material', 'refresh_icon': 'refresh',
    'location_icon_family': 'Material', 'location_icon': 'location_on_outlined',
    'visible_pages': <String, dynamic>{},
    'actions': <dynamic>[],
  };

  static const presets = <Map<String, dynamic>>[
    {'id':'amazon','name':'Amazon','background_color':'#FFD814','foreground_color':'#111111','height':82.0,'radius':8.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':false,'show_location':true},
    {'id':'flipkart','name':'Flipkart','background_color':'#2874F0','foreground_color':'#FFFFFF','height':78.0,'radius':12.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'myntra','name':'Myntra','background_color':'#FFFFFF','foreground_color':'#282C3F','height':70.0,'radius':6.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':true,'show_location':false},
    {'id':'meesho','name':'Meesho','background_color':'#FCEAF3','foreground_color':'#7A174D','height':76.0,'radius':18.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'minimal','name':'Minimal','background_color':'#FFFFFF','foreground_color':'#202124','height':60.0,'radius':0.0,'position':'top','show_menu':false,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':false,'show_location':false},
    {'id':'premium','name':'Premium Dark','background_color':'#171923','foreground_color':'#FFFFFF','height':76.0,'radius':16.0,'position':'floating','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'location','name':'Location First','background_color':'#F0EAFE','foreground_color':'#35235F','height':96.0,'radius':14.0,'position':'top','show_menu':false,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':false,'show_location':true},
    {'id':'gradient','name':'Gradient','background_color':'#5B3A9E','foreground_color':'#FFFFFF','height':78.0,'radius':20.0,'position':'floating','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
    {'id':'compact','name':'Compact','background_color':'#FFFFFF','foreground_color':'#202124','height':52.0,'radius':4.0,'position':'top','show_menu':true,'show_logo':false,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':false,'show_location':false},
    {'id':'search','name':'Search Focus','background_color':'#F7F7F7','foreground_color':'#252525','height':68.0,'radius':24.0,'position':'floating','show_menu':false,'show_logo':false,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':false,'show_location':false},
    {'id':'fashion','name':'Fashion','background_color':'#FBE5E8','foreground_color':'#7A1F35','height':80.0,'radius':10.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':false,'show_wishlist':true,'show_location':false},
    {'id':'custom','name':'Custom','background_color':'#FFFFFF','foreground_color':'#24212B','height':72.0,'radius':12.0,'position':'top','show_menu':true,'show_logo':true,'show_search':true,'show_cart':true,'show_voice_search':true,'show_wishlist':true,'show_location':false},
  ];

  static Color color(String value, {Color fallback = Colors.white}) {
    final raw = value.replaceFirst('#', '');
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return fallback;
    return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}

class DesignerAppBarBuilderPage extends StatefulWidget {
  const DesignerAppBarBuilderPage({
    super.key,
    required this.initialConfig,
    required this.availablePages,
    required this.onUpload,
    required this.onSave,
  });
  final DesignerAppBarConfig initialConfig;
  final List<Map<String, String>> availablePages;
  final Future<Map<String, dynamic>?> Function() onUpload;
  final ValueChanged<DesignerAppBarConfig> onSave;

  @override
  State<DesignerAppBarBuilderPage> createState() => _DesignerAppBarBuilderPageState();
}

class _DesignerAppBarBuilderPageState extends State<DesignerAppBarBuilderPage> {
  late Map<String, dynamic> data;
  final _color = TextEditingController();
  final _placeholder = TextEditingController();

  @override
  void initState() {
    super.initState();
    data = widget.initialConfig.toJson();
    _color.text = (data['background_color'] ?? '#FFFFFF').toString();
    _placeholder.text = (data['search_placeholder'] ?? 'Search products...').toString();
  }

  @override
  void dispose() {
    _color.dispose();
    _placeholder.dispose();
    super.dispose();
  }

  void _set(String key, dynamic value) => setState(() => data[key] = value);

  Future<void> _upload(String target) async {
    final media = await widget.onUpload();
    if (media == null || !mounted) return;
    final url = (media['source_url'] ?? media['url'] ?? '').toString();
    if (url.isEmpty) return;
    setState(() {
      data[target] = url;
      if (target == 'background_image_url') data['background_mime_type'] = (media['mime_type'] ?? '').toString();
    });
  }

  Future<void> _chooseIcon(String key) async {
    final choice = await showDialog<NavIconChoice>(
      context: context,
      builder: (ctx) => const _AppBarIconPickerDialog(),
    );
    if (choice == null || !mounted) return;
    setState(() {
      data['${key}_family'] = choice.family;
      data[key] = choice.name;
    });
  }

  Future<void> _addAction() async {
    final actions = List<Map<String, dynamic>>.from(DesignerAppBarConfig(json: data).actions);
    if (actions.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can add up to 10 custom App Bar actions.')));
      return;
    }
    actions.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'label': 'Action ${actions.length + 1}',
      'icon_family': 'Material',
      'icon': 'star_outline',
      'link_type': 'page',
      'link_value': 'home',
      'visible': true,
    });
    _set('actions', actions);
  }

  Future<void> _editActionIcon(int index) async {
    final choice = await showDialog<NavIconChoice>(context: context, builder: (_) => const _AppBarIconPickerDialog());
    if (choice == null || !mounted) return;
    final actions = DesignerAppBarConfig(json: data).actions;
    actions[index]['icon_family'] = choice.family;
    actions[index]['icon'] = choice.name;
    _set('actions', actions);
  }

  Widget _switch(String key, String label, IconData icon) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    secondary: Icon(icon, color: _appBarPurple),
    title: Text(label),
    value: data[key] != false,
    onChanged: (value) => _set(key, value),
  );

  Widget _presetCard(Map<String, dynamic> preset) {
    final selected = data['preset'] == preset['id'];
    final bg = DesignerAppBarConfig.color(preset['background_color'].toString());
    final fg = DesignerAppBarConfig.color(preset['foreground_color'].toString(), fallback: Colors.black);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        data.addAll(preset);
        data['background_color'] = preset['background_color'];
        data['preset'] = preset['id'];
        _color.text = data['background_color'].toString();
      }),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? _appBarPurple.withOpacity(.10) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _appBarPurple : Theme.of(context).dividerColor, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
            child: Row(children: [
              Icon(Icons.menu, size: 15, color: fg),
              const SizedBox(width: 5),
              Expanded(child: Container(height: 17, decoration: BoxDecoration(color: fg.withOpacity(.12), borderRadius: BorderRadius.circular(12)))),
              Icon(Icons.shopping_cart_outlined, size: 15, color: fg),
            ]),
          ),
          const SizedBox(height: 7),
          Text(preset['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _preview() {
    final config = DesignerAppBarConfig(json: data);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: Colors.black.withOpacity(.04),
          child: const Text('LIVE PREVIEW · GLOWHIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8)),
        ),
        SizedBox(
          height: config.height.clamp(54, 112),
          child: DesignerAppBarView(
            config: config,
            pageKey: 'home',
            cartCount: 2,
            searchController: TextEditingController(text: ''),
            onMenu: () {},
            onCart: () {},
            onSearch: () {},
            onVoiceSearch: () {},
            onWishlist: () {},
            onRefresh: () {},
            onLocation: () {},
            onCustomAction: (_) {},
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = DesignerAppBarConfig(json: data);
    return Scaffold(
      appBar: AppBar(title: const Text('App Bar Builder'), actions: [
        TextButton(onPressed: () {
          final normalized = DesignerAppBarConfig(json: data);
          widget.onSave(normalized);
          Navigator.pop(context);
        }, child: const Text('Apply')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _preview(),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('12 Ready-made App Bars', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('${DesignerAppBarConfig.presets.length} designs', style: const TextStyle(color: Colors.grey)),
        ]),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: DesignerAppBarConfig.presets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.15, crossAxisSpacing: 9, mainAxisSpacing: 9),
          itemBuilder: (_, index) => _presetCard(DesignerAppBarConfig.presets[index]),
        ),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Header Controls', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          _switch('enabled', 'Enable App Bar', Icons.visibility_outlined),
          _switch('show_menu', 'Menu button', Icons.menu),
          _switch('show_logo', 'Logo', Icons.image_outlined),
          _switch('show_cart', 'Cart', Icons.shopping_cart_outlined),
          _switch('show_voice_search', 'Voice Search', Icons.mic_none),
          _switch('show_search', 'Search', Icons.search),
          _switch('show_wishlist', 'Wishlist', Icons.favorite_border),
          _switch('show_refresh', 'Refresh', Icons.refresh),
          _switch('show_location', 'Address / Location', Icons.location_on_outlined),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Icon Library', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          for (final item in [
            ('menu_icon', 'Menu Icon', Icons.menu),
            ('cart_icon', 'Cart Icon', Icons.shopping_cart_outlined),
            ('voice_icon', 'Voice Search Icon', Icons.mic_none),
            ('search_icon', 'Search Icon', Icons.search),
            ('wishlist_icon', 'Wishlist Icon', Icons.favorite_border),
            ('refresh_icon', 'Refresh Icon', Icons.refresh),
            ('location_icon', 'Location Icon', Icons.location_on_outlined),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: DesignerNavIcons.icon((data['${item.$1}_family'] ?? 'Material').toString(), (data[item.$1] ?? '').toString(), color: _appBarPurple),
              title: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _chooseIcon(item.$1),
            ),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Logo & Background', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Upload Logo'),
            subtitle: Text(config.logoUrl.isEmpty ? 'No logo selected' : 'Logo uploaded'),
            onTap: () => _upload('logo_url'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wallpaper_outlined),
            title: const Text('Upload Background Image / GIF'),
            subtitle: Text(config.backgroundImageUrl.isEmpty ? 'No background selected' : 'Background media uploaded'),
            onTap: () => _upload('background_image_url'),
          ),
          TextField(controller: _color, decoration: const InputDecoration(labelText: 'Background HEX colour', hintText: '#FFFFFF'), onChanged: (v) => _set('background_color', v)),
          TextField(controller: _placeholder, decoration: const InputDecoration(labelText: 'Search placeholder'), onChanged: (v) => _set('search_placeholder', v)),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dimensions & Position', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          _slider('Header Height', 'height', 48, 160, 1),
          _slider('Icon / Item Spacing', 'spacing', 0, 32, 1),
          _slider('Corner Radius', 'radius', 0, 36, 1),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: config.position,
            decoration: const InputDecoration(labelText: 'Header Position'),
            items: const [
              DropdownMenuItem(value: 'top', child: Text('Top / Standard')),
              DropdownMenuItem(value: 'floating', child: Text('Floating / Rounded')),
              DropdownMenuItem(value: 'overlay', child: Text('Overlay Style')),
            ],
            onChanged: (v) => _set('position', v ?? 'top'),
          ),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Page Visibility', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const Text('Choose where this App Bar should appear.'),
          for (final page in widget.availablePages)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(page['title'] ?? page['key'] ?? ''),
              value: (data['visible_pages'] as Map?)?[page['key']] != false,
              onChanged: (v) {
                final map = Map<String, dynamic>.from(data['visible_pages'] as Map? ?? {});
                map[page['key'] ?? 'home'] = v ?? true;
                _set('visible_pages', map);
              },
            ),
        ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Custom Action Buttons', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            TextButton.icon(onPressed: config.actions.length >= 10 ? null : _addAction, icon: const Icon(Icons.add), label: const Text('Add')),
          ]),
          Text('${config.actions.length}/10 actions'),
          for (var i = 0; i < config.actions.length; i++) _actionEditor(i, config.actions[i]),
        ]))),
        const SizedBox(height: 24),
        SizedBox(height: 52, child: FilledButton.icon(
          onPressed: () {
            final normalized = DesignerAppBarConfig(json: data);
            widget.onSave(normalized);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Apply Selected App Bar'),
        )),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _slider(String label, String key, double min, double max, double step) {
    final value = ((data[key] as num?)?.toDouble() ?? min).clamp(min, max);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value.toStringAsFixed(0))]),
      Slider(value: value, min: min, max: max, divisions: ((max - min) / step).round(), onChanged: (v) => _set(key, v)),
    ]);
  }

  Widget _actionEditor(int index, Map<String, dynamic> action) {
    final actions = DesignerAppBarConfig(json: data).actions;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Choose icon',
            onPressed: () => _editActionIcon(index),
            icon: DesignerNavIcons.icon((action['icon_family'] ?? 'Material').toString(), (action['icon'] ?? 'star_outline').toString(), color: _appBarPurple, size: 25),
          ),
          Expanded(child: TextFormField(initialValue: action['label'].toString(), decoration: const InputDecoration(labelText: 'Button label', isDense: true), onChanged: (v) { actions[index]['label'] = v; _set('actions', actions); })),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () { actions.removeAt(index); _set('actions', actions); }),
        ]),
        DropdownButtonFormField<String>(
          value: (action['link_type'] ?? 'page').toString(),
          decoration: const InputDecoration(labelText: 'Destination type'),
          items: const [
            DropdownMenuItem(value: 'page', child: Text('App Page')),
            DropdownMenuItem(value: 'url', child: Text('Website URL')),
            DropdownMenuItem(value: 'deep_link', child: Text('App Deep Link')),
          ],
          onChanged: (v) { actions[index]['link_type'] = v ?? 'page'; _set('actions', actions); },
        ),
        TextFormField(initialValue: action['link_value'].toString(), decoration: const InputDecoration(labelText: 'Destination (home / cart / https://...)'), onChanged: (v) { actions[index]['link_value'] = v; _set('actions', actions); }),
      ])),
    );
  }
}

class DesignerAppBarView extends StatelessWidget {
  const DesignerAppBarView({
    super.key,
    required this.config,
    required this.pageKey,
    required this.cartCount,
    required this.searchController,
    required this.onMenu,
    required this.onCart,
    required this.onSearch,
    required this.onVoiceSearch,
    required this.onWishlist,
    required this.onRefresh,
    required this.onLocation,
    required this.onCustomAction,
  });
  final DesignerAppBarConfig config;
  final String pageKey;
  final int cartCount;
  final TextEditingController searchController;
  final VoidCallback onMenu, onCart, onSearch, onVoiceSearch, onWishlist, onRefresh, onLocation;
  final ValueChanged<Map<String, dynamic>> onCustomAction;

  @override
  Widget build(BuildContext context) {
    if (!config.enabled || !config.visibleOn(pageKey)) return const SizedBox.shrink();
    final fg = DesignerAppBarConfig.color((config.toJson()['foreground_color'] ?? '#202124').toString(), fallback: Colors.black);
    final bg = DesignerAppBarConfig.color(config.backgroundColor);
    final data = config.toJson();
    final content = Container(
      height: config.height,
      padding: EdgeInsets.symmetric(horizontal: config.spacing.clamp(0, 24)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(config.position == 'floating' ? config.radius : 0),
        image: config.backgroundImageUrl.isEmpty ? null : DecorationImage(
          image: NetworkImage(config.backgroundImageUrl),
          fit: BoxFit.cover,
          onError: (_, __) {},
        ),
        boxShadow: config.position == 'floating' ? [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 3))] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (config.show('show_location'))
          InkWell(onTap: onLocation, child: Row(children: [
            DesignerNavIcons.icon((data['location_icon_family'] ?? 'Material').toString(), (data['location_icon'] ?? 'location_on_outlined').toString(), color: fg, size: 17),
            const SizedBox(width: 4),
            Expanded(child: Text('Deliver to your address', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 11))),
          ])),
        Row(children: [
          if (config.show('show_menu')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onMenu,
            icon: DesignerNavIcons.icon((data['menu_icon_family'] ?? 'Material').toString(), (data['menu_icon'] ?? 'menu').toString(), color: fg),
          ),
          if (config.show('show_logo') && config.logoUrl.isNotEmpty)
            Padding(padding: const EdgeInsets.only(right: 7), child: Image.network(config.logoUrl, width: 34, height: 34, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          if (config.show('show_logo') && config.logoUrl.isEmpty)
            Padding(padding: const EdgeInsets.only(right: 7), child: Text('GlowHit', style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16))),
          if (config.show('show_search'))
            Expanded(child: InkWell(
              onTap: onSearch,
              borderRadius: BorderRadius.circular(config.radius),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.94), borderRadius: BorderRadius.circular(config.radius)),
                child: Row(children: [
                  DesignerNavIcons.icon((data['search_icon_family'] ?? 'Material').toString(), (data['search_icon'] ?? 'search').toString(), color: Colors.black54, size: 20),
                  const SizedBox(width: 7),
                  Expanded(child: Text(config.toJson()['search_placeholder'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black38, fontSize: 12))),
                ]),
              ),
            ))
          else
            const Spacer(),
          if (config.show('show_voice_search')) IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Voice Search',
            onPressed: onVoiceSearch,
            icon: DesignerNavIcons.icon((data['voice_icon_family'] ?? 'Material').toString(), (data['voice_icon'] ?? 'mic_none').toString(), color: fg),
          ),
          if (config.show('show_wishlist')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onWishlist,
            icon: DesignerNavIcons.icon((data['wishlist_icon_family'] ?? 'Material').toString(), (data['wishlist_icon'] ?? 'favorite_border').toString(), color: fg),
          ),
          if (config.show('show_cart')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onCart,
            icon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: DesignerNavIcons.icon((data['cart_icon_family'] ?? 'Material').toString(), (data['cart_icon'] ?? 'shopping_cart_outlined').toString(), color: fg)),
          ),
          if (config.show('show_refresh')) IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRefresh,
            icon: DesignerNavIcons.icon((data['refresh_icon_family'] ?? 'Material').toString(), (data['refresh_icon'] ?? 'refresh').toString(), color: fg),
          ),
          for (final action in config.actions.where((a) => a['visible'] != false))
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: (action['label'] ?? 'Action').toString(),
              onPressed: () => onCustomAction(action),
              icon: DesignerNavIcons.icon((action['icon_family'] ?? 'Material').toString(), (action['icon'] ?? 'star_outline').toString(), color: fg, size: 21),
            ),
        ]),
      ]),
    );
    return content;
  }
}

class _AppBarIconPickerDialog extends StatefulWidget {
  const _AppBarIconPickerDialog();
  @override
  State<_AppBarIconPickerDialog> createState() => _AppBarIconPickerDialogState();
}

class _AppBarIconPickerDialogState extends State<_AppBarIconPickerDialog> {
  String query = '';
  String family = 'All';
  @override
  Widget build(BuildContext context) {
    final icons = DesignerNavIcons.all.where((icon) {
      final text = '${icon.name} ${icon.label}'.toLowerCase();
      return (family == 'All' || icon.family == family) && (query.isEmpty || text.contains(query.toLowerCase()));
    }).toList();
    return AlertDialog(
      title: const Text('Choose Icon'),
      content: SizedBox(width: 360, height: 440, child: Column(children: [
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search all icons'), onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: family,
          items: ['All', ...DesignerNavIcons.families].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => family = v ?? 'All'),
        ),
        const SizedBox(height: 8),
        Expanded(child: GridView.builder(
          itemCount: icons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 5, mainAxisSpacing: 5),
          itemBuilder: (_, i) => InkWell(
            onTap: () => Navigator.pop(context, icons[i]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              DesignerNavIcons.icon(icons[i].family, icons[i].name, color: _appBarPurple, size: 24),
              Text(icons[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
            ]),
          ),
        )),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
