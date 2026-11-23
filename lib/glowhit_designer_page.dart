import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'customer_account_page.dart';

const _designerPurple = Color(0xFF51408F);
const _designerBackground = Color(0xFFF7F5FB);

class DesignerComponent {
  DesignerComponent({
    required this.id,
    required this.type,
    required this.title,
    required this.layout,
    Map<String, dynamic>? properties,
    this.enabled = true,
  }) : properties = properties ?? <String, dynamic>{};

  final String id;
  final String type;
  String title;
  String layout;
  bool enabled;
  final Map<String, dynamic> properties;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'layout': layout,
    'enabled': enabled,
    'properties': properties,
  };

  factory DesignerComponent.fromJson(Map<String, dynamic> json) => DesignerComponent(
    id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
    type: (json['type'] ?? 'banner').toString(),
    title: (json['title'] ?? 'New component').toString(),
    layout: (json['layout'] ?? 'Grid').toString(),
    enabled: json['enabled'] != false,
    properties: json['properties'] is Map
      ? Map<String, dynamic>.from(json['properties'] as Map)
      : <String, dynamic>{},
  );
}

class GlowHitDesignerPage extends StatefulWidget {
  const GlowHitDesignerPage({super.key, required this.token, this.loadRemoteConfig = true});
  final String token;
  final bool loadRemoteConfig;

  @override
  State<GlowHitDesignerPage> createState() => _GlowHitDesignerPageState();
}

class _GlowHitDesignerPageState extends State<GlowHitDesignerPage> {
  static const _storageKey = 'glowhit_designer_draft_v1';
  static const _pages = ['Home', 'Search', 'Categories', 'Wishlist', 'Product', 'Account'];
  static const _layoutTypes = <String, List<String>>{
    'Banner': ['Banner Grid', 'Banner List', 'Banner Scroll', 'Banner Slider'],
    'Category': ['Category List', 'Category Grid', 'Category List Tile', 'Category Slider', 'Category Scroll'],
    'Product': ['Product Grid', 'Product Slider', 'Product List'],
    'Other': ['Existing section'],
  };
  static const _defaultComponents = <String, List<Map<String, dynamic>>>{
    'Home': [
      {'type': 'Banner', 'title': 'Main promotional banner', 'layout': 'Banner Slider'},
      {'type': 'Category', 'title': 'Shop by category', 'layout': 'Category Grid'},
      {'type': 'Product', 'title': 'Featured products', 'layout': 'Product Grid'},
      {'type': 'Product', 'title': 'Best sellers', 'layout': 'Product Slider'},
    ],
    'Search': [],
    'Wishlist': [],
    'Product': [
      {'type': 'Product', 'title': 'Product gallery and details', 'layout': 'Product List'},
      {'type': 'Banner', 'title': 'Related products banner', 'layout': 'Banner Scroll'},
    ],
    'Categories': [
      {'type': 'Category', 'title': 'All categories', 'layout': 'Category Grid'},
      {'type': 'Product', 'title': 'Category products', 'layout': 'Product Grid'},
    ],
    'Account': [
      {'type': 'Banner', 'title': 'Account welcome card', 'layout': 'Banner List'},
    ],
  };

  String selectedPage = 'Home';
  String? selectedId;
  bool loading = true;
  bool saving = false;
  bool publishing = false;
  String? error;
  Map<String, List<DesignerComponent>> pages = {};
  Map<String, dynamic> templates = {};
  late final TextEditingController _titleController = TextEditingController();
  late final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  String _wordpressPageKey(String page) => switch (page) {
    'Home' => 'home',
    'Search' => 'search',
    'Categories' => 'categories',
    'Wishlist' => 'wishlist',
    'Product' => 'product',
    'Account' => 'account',
    _ => page.toLowerCase(),
  };

  Future<DesignerComponent> _fromWordPressSection(Map<String, dynamic> section) async {
    final rawType = (section['designer_component_type'] ?? section['type'] ?? '').toString().toLowerCase();
    String type = 'Other';
    String layout = 'Existing section';
    if (rawType.startsWith('banner') || rawType == 'ark_live_slider') {
      type = 'Banner';
      layout = switch (rawType) {
        'banner_grid' => 'Banner Grid',
        'banner_list' => 'Banner List',
        'banner_scroll' => 'Banner Scroll',
        _ => 'Banner Slider',
      };
    } else if (rawType.startsWith('category')) {
      type = 'Category';
      layout = switch (rawType) {
        'category_list' => 'Category List',
        'category_list_tile' => 'Category List Tile',
        'category_slider' => 'Category Slider',
        'category_scroll' => 'Category Scroll',
        _ => 'Category Grid',
      };
    } else if (rawType.startsWith('product')) {
      type = 'Product';
      layout = switch (rawType) {
        'product_list' => 'Product List',
        'product_carousel' || 'product_slider' => 'Product Slider',
        _ => 'Product Grid',
      };
    }

    final properties = Map<String, dynamic>.from(section);
    properties['background_color'] = section['section_background'] ?? section['background_color'] ?? '#FFFFFF';
    properties['title_color'] = section['text_color'] ?? section['title_color'] ?? '#241D33';
    properties['height'] = section['height_px'] ?? section['height'] ?? 180;
    properties['width'] = ((section['width_pct'] as num?)?.toDouble() ?? 100) / 100;
    properties['max_cross_axis_extent'] = section['max_width_px'] ?? 300;
    properties['main_axis_spacing'] = section['item_gap'] ?? 10;
    properties['cross_axis_spacing'] = section['item_gap'] ?? 10;
    properties['border_radius'] = section['corner_radius'] ?? 16;
    properties['cross_axis_count'] = section['columns'] ?? 2;
    properties['cross_aspect_ratio'] = section['card_aspect_ratio'] ?? 1;
    properties['elevation'] = section['card_depth'] ?? 1;
    properties['fixed_grid_view_count'] = section['limit'] ?? 12;
    properties['parent_category_id'] = section['category_id'] ?? 0;
    properties['show_all_categories'] = (section['limit'] as num?)?.toInt() == 100;
    properties['arrows'] = section['show_arrows'] ?? false;
    properties['dots'] = section['show_dots'] ?? false;
    properties['view_fraction'] = section['card_width'] ?? 1;
    properties['pause'] = section['pause_on_interaction'] ?? true;
    properties['link'] = section['tap_url'] ?? '';
    properties['image_url'] = section['image_url'] ?? section['background_image_url'] ?? '';
    properties['children'] = section['children'] ?? section['slides'] ?? <dynamic>[];

    final sliderKey = (section['slider_key'] ?? '').toString();
    if (sliderKey.isNotEmpty) {
      try {
        final uri = Uri.parse('https://pluginstore.shop/wp-json/ark-designer/v1/sliders/$sliderKey');
        final response = await http.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['slides'] is List) {
            properties['children'] = payload['slides'];
            properties['slider_settings'] = payload['settings'] is Map
                ? Map<String, dynamic>.from(payload['settings'] as Map)
                : <String, dynamic>{};
          }
        }
      } catch (_) {
        // Keep the last saved section data visible when the SQL slider endpoint is offline.
      }
    }

    return DesignerComponent(
      id: (section['id'] ?? _id()).toString(),
      type: type,
      title: (section['title'] ?? 'New component').toString(),
      layout: layout,
      enabled: section['visible'] != false,
      properties: properties,
    );
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.loadRemoteConfig) {
      try {
        final remote = await ArkCustomerApi(widget.token).request('designer/config');
        if (remote is Map && remote['pages'] is Map) {
          final remotePages = Map<String, dynamic>.from(remote['pages'] as Map);
          for (final page in _pages) {
            final pageConfig = remotePages[_wordpressPageKey(page)];
            final sections = pageConfig is Map && pageConfig['sections'] is List
                ? pageConfig['sections'] as List
                : <dynamic>[];
            pages[page] = <DesignerComponent>[];
            for (final section in sections) {
              if (section is Map) {
                pages[page]!.add(await _fromWordPressSection(Map<String, dynamic>.from(section)));
              }
            }
          }
        }
      } catch (e) {
        error = 'WordPress Designer config could not be loaded: $e';
      }
    }

    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['pages'] is Map) {
          pages = (decoded['pages'] as Map).map((key, value) => MapEntry(
            key.toString(),
            (value as List).whereType<Map>().map((item) =>
              DesignerComponent.fromJson(Map<String, dynamic>.from(item))).toList(),
          ));
          if (decoded['templates'] is Map) {
            templates = Map<String, dynamic>.from(decoded['templates'] as Map);
          }
        }
      } catch (_) {
        error = 'Saved draft could not be read. A fresh draft was loaded.';
      }
    }

    for (final page in _pages) {
      pages.putIfAbsent(page, () => (_defaultComponents[page] ?? <Map<String, dynamic>>[]).map((item) =>
        DesignerComponent(id: _id(), type: item['type'] as String, title: item['title'] as String,
          layout: item['layout'] as String)).toList());
    }
    if (pages[selectedPage]?.isNotEmpty == true) selectedId = pages[selectedPage]!.first.id;
    if (mounted) setState(() => loading = false);
  }

  List<DesignerComponent> get currentComponents => pages[selectedPage] ?? <DesignerComponent>[];
  DesignerComponent? get selectedComponent {
    for (final component in currentComponents) {
      if (component.id == selectedId) return component;
    }
    return null;
  }

  Future<void> _persist({bool publish = false}) async {
    setState(() { saving = !publish; publishing = publish; error = null; });
    try {
      final data = <String, dynamic>{
        'schema': 'ark-glowhit-designer/v1',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'pages': pages.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())),
        'templates': templates,
      };
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, json);
      try {
        await ArkCustomerApi(widget.token).request('designer/config', method: 'POST', body: {
          'config': data,
          'schema': 'ark-glowhit-designer/v1',
          'status': publish ? 'published' : 'draft',
        });
      } catch (e) {
        // The device draft remains available, but do not claim WordPress saved or published it.
        if (mounted) setState(() => error = publish
            ? 'Draft is saved on this device, but WordPress did not confirm Publish: $e'
            : 'Draft is saved on this device, but WordPress did not confirm the server draft: $e');
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(publish ? 'Published configuration synced to WordPress.' : 'Designer draft saved on this device.'),
      ));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() { saving = false; publishing = false; });
    }
  }

  Future<void> _selectPage(String? page) async {
    if (page == null || !_pages.contains(page)) return;
    setState(() {
      selectedPage = page;
      selectedId = pages[page]?.isNotEmpty == true ? pages[page]!.first.id : null;
    });
  }

  Future<void> _addComponent(String type) async {
    final layout = _layoutTypes[type]!.first;
    final item = DesignerComponent(
      id: _id(),
      type: type,
      title: 'New $type component',
      layout: layout,
      properties: <String, dynamic>{
        'background_color': '#FFFFFF',
        'title_color': '#241D33',
        'description': '',
        'show_title': true,
        'countdown_enabled': false,
        'padding_top': 12.0, 'padding_bottom': 12.0, 'padding_left': 12.0, 'padding_right': 12.0,
        'margin_top': 0.0, 'margin_bottom': 0.0, 'margin_left': 0.0, 'margin_right': 0.0,
        'height': 180.0, 'width': 1.0, 'max_cross_axis_extent': 300.0,
        'main_axis_spacing': 10.0, 'cross_axis_spacing': 10.0, 'border_radius': 16.0,
        'horizontal': true, 'cross_axis_count': 2, 'cross_aspect_ratio': 1.0,
        'elevation': 1.0, 'fixed_grid_view_count': 2,
      },
    );
    setState(() { currentComponents.add(item); selectedId = item.id; });
    await _persist();
  }

  Future<void> _removeComponent(DesignerComponent item) async {
    setState(() {
      currentComponents.removeWhere((component) => component.id == item.id);
      selectedId = currentComponents.isEmpty ? null : currentComponents.first.id;
    });
    await _persist();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = currentComponents.removeAt(oldIndex);
      currentComponents.insert(newIndex, item);
    });
    await _persist();
  }

  Future<void> _showComponentPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add a component', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            for (final type in _layoutTypes.keys)
              ListTile(
                leading: _componentIcon(type, size: 30),
                title: Text('$type layout'),
                subtitle: Text(_layoutTypes[type]!.join(' • ')),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () { Navigator.pop(sheetContext); _addComponent(type); },
              ),
          ]),
        ),
      ),
    );
  }

  Icon _componentIcon(String type, {double size = 24}) {
    final icon = switch (type) {
      'Banner' => Icons.view_carousel_rounded,
      'Category' => Icons.category_rounded,
      'Product' => Icons.shopping_bag_rounded,
      _ => Icons.widgets_rounded,
    };
    return Icon(icon, color: _designerPurple, size: size);
  }

  Future<Map<String, dynamic>?> _chooseMedia() async {
    final response = await ArkCustomerApi(widget.token).request(
      'designer/media',
      query: {'page': '1', 'per_page': '48'},
    );
    final rows = response is Map && response['items'] is List
        ? (response['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    if (!mounted) return null;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .72,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.photo_library_outlined, color: _designerPurple),
                SizedBox(width: 10),
                Text('WordPress Media Library', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No images found in WordPress Media Library.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (_, index) {
                        final item = rows[index];
                        final image = (item['thumbnail_url'] ?? item['source_url'] ?? '').toString();
                        return InkWell(
                          onTap: () => Navigator.pop(ctx, item),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(children: [
                              Expanded(
                                child: image.isEmpty
                                    ? const Icon(Icons.image_not_supported_outlined)
                                    : Image.network(image, width: double.infinity, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(5),
                                child: Text((item['title'] ?? 'Image').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }


  Widget _componentVisual(DesignerComponent component, {bool compact = false}) {
    final bg = _color(component.properties['background_color']?.toString() ?? '#F0ECF8');
    final titleColor = _color(component.properties['title_color']?.toString() ?? '#241D33');
    final children = component.properties['children'] is List ? component.properties['children'] as List : const <dynamic>[];
    final firstChild = children.isNotEmpty && children.first is Map ? Map<String, dynamic>.from(children.first as Map) : <String, dynamic>{};
    final previewImage = (component.properties['image_url'] ?? component.properties['background_image_url'] ?? firstChild['image_url'] ?? firstChild['source_url'] ?? firstChild['url'] ?? '').toString();
    final height = compact ? 78.0 : ((component.properties['height'] as num?)?.toDouble() ?? 160.0).clamp(90.0, 280.0);
    return Container(
      height: height,
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        (component.properties['margin_left'] as num?)?.toDouble() ?? 0,
        (component.properties['margin_top'] as num?)?.toDouble() ?? 0,
        (component.properties['margin_right'] as num?)?.toDouble() ?? 0,
        (component.properties['margin_bottom'] as num?)?.toDouble() ?? 0,
      ),
      padding: EdgeInsets.fromLTRB(
        (component.properties['padding_left'] as num?)?.toDouble() ?? 12,
        (component.properties['padding_top'] as num?)?.toDouble() ?? 12,
        (component.properties['padding_right'] as num?)?.toDouble() ?? 12,
        (component.properties['padding_bottom'] as num?)?.toDouble() ?? 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular((component.properties['border_radius'] as num?)?.toDouble() ?? 16),
        boxShadow: [
          if (((component.properties['elevation'] as num?)?.toDouble() ?? 0) > 0)
            BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(children: [
        if (previewImage.isNotEmpty)
          Positioned(
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: compact ? 76 : 112,
                height: compact ? 54 : 78,
                child: Image.network(
                  previewImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: titleColor.withValues(alpha: .08), child: const Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        Positioned(right: 4, top: 2, child: _componentIcon(component.type, size: compact ? 26 : 36)),
        Align(alignment: Alignment.centerLeft, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(component.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: titleColor, fontWeight: FontWeight.w800, fontSize: compact ? 12 : 16)),
          if (!compact && (component.properties['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(component.properties['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: titleColor.withValues(alpha: .7), fontSize: 12)),
          ],
          const SizedBox(height: 7),
          Container(height: 6, width: 110, decoration: BoxDecoration(color: titleColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 5),
          Container(height: 6, width: 78, decoration: BoxDecoration(color: titleColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(10))),
        ])),
      ]),
    );
  }

  Color _color(String input) {
    final value = input.replaceFirst('#', '');
    final parsed = int.tryParse(value, radix: 16);
    return Color(parsed == null ? 0xFFF0ECF8 : (value.length == 6 ? 0xFF000000 | parsed : parsed));
  }

  void _editComponent(DesignerComponent item) {
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => _DesignerComponentEditor(
      component: item,
      onChanged: () { if (mounted) setState(() {}); },
      onSave: () => _persist(),
      onDelete: () => _removeComponent(item),
      visualBuilder: () => _componentVisual(item),
      onChooseMedia: _chooseMedia,
    )));
  }

  Future<void> _openTemplates() async {
    final action = await showModalBottomSheet<String>(
      context: context, showDragHandle: true,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const ListTile(title: Text('Templates', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
        ListTile(leading: const Icon(Icons.dashboard_customize_rounded), title: const Text('Save current page as template'),
          onTap: () => Navigator.pop(ctx, 'save')),
        ListTile(leading: const Icon(Icons.collections_bookmark_rounded), title: const Text('Use a starter template'),
          onTap: () => Navigator.pop(ctx, 'starter')),
      ])),
    );
    if (action == 'save') {
      final nameController = TextEditingController();
      final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Save template'),
        content: TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(labelText: 'Template name')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, nameController.text.trim()), child: const Text('Save'))],
      ));
      nameController.dispose();
      if (name != null && name.isNotEmpty) {
        templates[name] = currentComponents.map((e) => e.toJson()).toList();
        await _persist();
      }
    } else if (action == 'starter') {
      final name = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
        title: const Text('Choose a starter template'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Fashion storefront'), child: const Text('Fashion storefront')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'Deals storefront'), child: const Text('Deals storefront')),
        ],
      ));
      if (name != null) {
        setState(() {
          currentComponents
            ..clear()
            ..addAll(_defaultComponents['Home']!.map((e) => DesignerComponent(id: _id(), type: e['type'] as String, title: e['title'] as String, layout: e['layout'] as String)));
        });
        await _persist();
      }
    }
  }

  Future<void> _openMyTemplates() async {
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved templates yet. Use Templates → Save current page as template.')));
      return;
    }
    final name = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('My Templates'),
      children: templates.keys.map((name) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, name.toString()), child: Text(name.toString()))).toList(),
    ));
    if (name != null && templates[name] is List) {
      setState(() {
        pages[selectedPage] = (templates[name] as List).whereType<Map>().map((item) =>
          DesignerComponent.fromJson(Map<String, dynamic>.from(item))).toList();
        selectedId = pages[selectedPage]!.firstOrNull?.id;
      });
      await _persist();
    }
  }

  Future<void> _openReorder() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => _DesignerReorderPage(
      components: currentComponents,
      onReorder: _reorder,
      iconBuilder: _componentIcon,
      previewBuilder: _componentVisual,
    )));
  }

  Widget _designerMenu() => PopupMenuButton<String>(
    icon: const Icon(Icons.menu_rounded),
    tooltip: 'Designer menu',
    onSelected: (value) {
      if (value == 'reorder') _openReorder();
      if (value == 'templates') _openTemplates();
      if (value == 'my_templates') _openMyTemplates();
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'reorder', child: ListTile(leading: Icon(Icons.reorder), title: Text('Reorder Components'), dense: true)),
      PopupMenuItem(value: 'templates', child: ListTile(leading: Icon(Icons.dashboard_customize), title: Text('Templates'), dense: true)),
      PopupMenuItem(value: 'my_templates', child: ListTile(leading: Icon(Icons.collections_bookmark), title: Text('My Templates'), dense: true)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: _designerBackground,
      appBar: AppBar(
        title: const Text('ARK Designer', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          _designerMenu(),
          PopupMenuButton<String>(
            tooltip: 'Designer settings',
            icon: const Icon(Icons.tune_rounded),
            onSelected: (value) {
              if (value == 'save') _persist();
              if (value == 'publish') _persist(publish: true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_outlined), title: Text('Save Draft'), dense: true)),
              PopupMenuItem(value: 'publish', child: ListTile(leading: Icon(Icons.publish_rounded), title: Text('Publish JSON'), dense: true)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComponentPicker,
        backgroundColor: _designerPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add component'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(children: [
            const Icon(Icons.edit_note_rounded, color: _designerPurple),
            const SizedBox(width: 8),
            const Text('Edit page', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: selectedPage,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11)),
              items: _pages.map((page) => DropdownMenuItem(value: page, child: Text(page))).toList(),
              onChanged: _selectPage,
            )),
          ]),
        ),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(error!, style: const TextStyle(color: Colors.red))),
        Expanded(child: currentComponents.isEmpty
          ? const Center(child: Text('No components on this page. Tap Add component.'))
          : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: currentComponents.length,
            itemBuilder: (context, index) {
              final component = currentComponents[index];
              final selected = component.id == selectedId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(19),
                  onTap: () => _editComponent(component),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: selected ? _designerPurple : const Color(0xFFE5E1EA), width: selected ? 2 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _componentIcon(component.type),
                        const SizedBox(width: 8),
                        Expanded(child: Text(component.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Switch(value: component.enabled, activeColor: _designerPurple, onChanged: (value) async { setState(() => component.enabled = value); await _persist(); }),
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editComponent(component)),
                      ]),
                      _componentVisual(component, compact: true),
                      Padding(padding: const EdgeInsets.only(top: 7, left: 4), child: Row(children: [
                        Text(component.layout, style: const TextStyle(color: _designerPurple, fontWeight: FontWeight.w700, fontSize: 12)),
                        const Spacer(),
                        Text('Tap to edit properties', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      ])),
                    ]),
                  ),
                ),
              );
            },
          )),
        if (saving || publishing) LinearProgressIndicator(value: null, color: _designerPurple),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: saving || publishing ? null : () => _persist(), icon: const Icon(Icons.save_outlined), label: const Text('Save Draft'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: saving || publishing ? null : () => _persist(publish: true), icon: const Icon(Icons.publish_rounded), label: const Text('Publish'))),
          ]),
        )),
      ]),
    );
  }
}

class _DesignerComponentEditor extends StatefulWidget {
  const _DesignerComponentEditor({
    required this.component,
    required this.onChanged,
    required this.onSave,
    required this.onDelete,
    required this.visualBuilder,
    required this.onChooseMedia,
  });

  final DesignerComponent component;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onDelete;
  final Widget Function() visualBuilder;
  final Future<Map<String, dynamic>?> Function() onChooseMedia;

  @override
  State<_DesignerComponentEditor> createState() => _DesignerComponentEditorState();
}

class _DesignerComponentEditorState extends State<_DesignerComponentEditor> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  DesignerComponent get item => widget.component;

  @override
  void initState() {
    super.initState();
    _title.text = item.title;
    _description.text = (item.properties['description'] ?? '').toString();
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }

  void _change(String key, dynamic value) {
    setState(() => item.properties[key] = value);
    widget.onChanged();
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: Color(0xFFE5E1EA))),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _designerPurple)),
        const SizedBox(height: 10),
        ...children,
      ])),
    ),
  );

  Widget _slider(String label, String key, {double min = 0, double max = 300}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(label)), Text(((item.properties[key] as num?)?.toDouble() ?? min).toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w700))]),
    Slider(value: ((item.properties[key] as num?)?.toDouble() ?? min).clamp(min, max), min: min, max: max,
      activeColor: _designerPurple, onChanged: (value) => _change(key, value)),
  ]);

  Widget _switch(String label, String key) => SwitchListTile(
    contentPadding: EdgeInsets.zero, title: Text(label), activeColor: _designerPurple,
    value: key == 'enabled' ? item.enabled : item.properties[key] == true,
    onChanged: (value) {
      if (key == 'enabled') {
        setState(() => item.enabled = value);
        widget.onChanged();
      } else {
        _change(key, value);
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final layouts = _GlowHitDesignerPageState._layoutTypes[item.type]!;
    return Scaffold(
      backgroundColor: _designerBackground,
      appBar: AppBar(
        title: const Text('Component Properties'),
        actions: [
          IconButton(tooltip: 'Delete component', icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () async { await widget.onDelete(); if (context.mounted) Navigator.pop(context); }),
          TextButton(onPressed: () async { await widget.onSave(); if (context.mounted) Navigator.pop(context); }, child: const Text('SAVE')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        Card(elevation: 0, clipBehavior: Clip.antiAlias, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LIVE COMPONENT PREVIEW', style: TextStyle(letterSpacing: 1.2, color: _designerPurple, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 10),
          widget.visualBuilder(),
        ]))),
        _section('Layout', [
          DropdownButtonFormField<String>(
            initialValue: layouts.contains(item.layout) ? item.layout : layouts.first,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Component layout'),
            items: layouts.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) { if (value != null) setState(() => item.layout = value); widget.onChanged(); },
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            onChanged: (value) { item.title = value; widget.onChanged(); setState(() {}); }),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            onChanged: (value) { _change('description', value); }),
          _switch('Show title', 'show_title'),
          _switch('Countdown enabled', 'countdown_enabled'),
        ]),
        _section('Color', [
          _colorChoice('Background colour', 'background_color', const ['#FFFFFF', '#F1ECFF', '#E8F6F0', '#FFF0E6', '#202033']),
          _colorChoice('Title colour', 'title_color', const ['#241D33', '#51408F', '#FFFFFF', '#B23B32', '#16734A']),
        ]),
        _section('Padding', [
          _slider('Top', 'padding_top'), _slider('Bottom', 'padding_bottom'),
          _slider('Left', 'padding_left'), _slider('Right', 'padding_right'),
        ]),
        _section('Margin', [
          _slider('Top', 'margin_top'), _slider('Bottom', 'margin_bottom'),
          _slider('Left', 'margin_left'), _slider('Right', 'margin_right'),
        ]),
        _section('Dimensions', [
          _slider('Height', 'height', min: 60, max: 320),
          _slider('Width factor', 'width', min: .5, max: 1),
          _slider('Max cross-axis extent', 'max_cross_axis_extent', min: 80, max: 420),
          _slider('Main-axis spacing', 'main_axis_spacing', max: 40),
          _slider('Cross-axis spacing', 'cross_axis_spacing', max: 40),
          _slider('Border radius', 'border_radius', max: 40),
          _slider('Cross-axis count', 'cross_axis_count', min: 1, max: 5),
          _slider('Cross aspect ratio', 'cross_aspect_ratio', min: .5, max: 2),
          _slider('Elevation', 'elevation', max: 12),
          _slider('Fixed grid view count', 'fixed_grid_view_count', min: 1, max: 8),
          _switch('Horizontal layout', 'horizontal'),
        ]),
        if (item.type == 'Banner') _section('Banner style', [
          _switch('Carousel controls', 'control'),
          _switch('Autoplay', 'autoplay'),
          _switch('Fade transition', 'fade'),
          _switch('Pause when touched', 'pause'),
          _switch('Show dots', 'dots'),
          _switch('Show arrows', 'arrows'),
          _slider('View fraction', 'view_fraction', min: .4, max: 1),
        ]),
        if (item.type == 'Category') _section('Category settings', [
          _switch('Show all categories', 'show_all_categories'),
          const Text('Parent category ID'),
          TextField(key: const ValueKey('parent_category_id'), keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0 = all categories'),
            onChanged: (v) => _change('parent_category_id', int.tryParse(v) ?? 0)),
        ]),
        if (item.type == 'Product') _section('Product settings', [
          DropdownButtonFormField<String>(
            initialValue: (item.properties['source'] ?? 'featured').toString(),
            decoration: const InputDecoration(labelText: 'Product source', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'featured', child: Text('Featured')),
              DropdownMenuItem(value: 'category', child: Text('Category')),
              DropdownMenuItem(value: 'tag', child: Text('Tag')),
              DropdownMenuItem(value: 'on_sale', child: Text('On Sale')),
              DropdownMenuItem(value: 'new_arrival', child: Text('New Arrival')),
              DropdownMenuItem(value: 'wishlist', child: Text('Wishlist')),
              DropdownMenuItem(value: 'best_selling', child: Text('Best Selling')),
            ],
            onChanged: (v) { if (v != null) _change('source', v); },
          ),
          TextField(decoration: const InputDecoration(labelText: 'Category / tag ID', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onChanged: (v) => _change('source_id', int.tryParse(v) ?? 0)),
        ]),
        _section('Visibility and children', [
          _switch('Component enabled', 'enabled'),
          TextField(decoration: const InputDecoration(labelText: 'Child reorder (comma-separated IDs)', border: OutlineInputBorder()),
            onChanged: (v) => _change('child_order', v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList())),
          TextField(decoration: const InputDecoration(labelText: 'Link / deep link', border: OutlineInputBorder()),
            onChanged: (v) => _change('link', v)),
          TextField(decoration: const InputDecoration(labelText: 'Image URL (optional)', border: OutlineInputBorder()),
            controller: TextEditingController(text: (item.properties['image_url'] ?? '').toString()),
            onChanged: (v) => _change('image_url', v)),
          FilledButton.icon(
            onPressed: () async {
              final media = await widget.onChooseMedia();
              if (media == null) return;
              final source = (media['source_url'] ?? '').toString();
              final child = <String, dynamic>{
                'attachment_id': media['id'],
                'image_url': source,
                'source_url': source,
                'title': (media['title'] ?? '').toString(),
                'alt_text': (media['alt_text'] ?? '').toString(),
                'link_type': 'in_app',
                'link_value': '',
                'active': true,
              };
              final existing = item.properties['children'] is List
                  ? (item.properties['children'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                  : <Map<String, dynamic>>[];
              existing.add(child);
              _change('children', existing);
              if ((item.properties['image_url'] ?? '').toString().isEmpty) _change('image_url', source);
            },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add image from WordPress Media Library'),
          ),
          if (item.properties['children'] is List)
            ...(item.properties['children'] as List).asMap().entries.map((entry) {
              final child = entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : <String, dynamic>{};
              final src = (child['image_url'] ?? child['source_url'] ?? '').toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(width: 52, height: 52, child: src.isEmpty
                    ? const Icon(Icons.image_outlined)
                    : Image.network(src, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
                title: Text((child['title'] ?? 'Banner image').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Media ID: ${child['attachment_id'] ?? '—'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    final updated = (item.properties['children'] as List).where((_, index) => index != entry.key).toList();
                    _change('children', updated);
                  },
                ),
              );
            }),
        ]),
      ]),
    );
  }

  Widget _colorChoice(String title, String key, List<String> choices) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title),
      Wrap(spacing: 10, children: choices.map((hex) => InkWell(
        onTap: () => _change(key, hex),
        child: Container(width: 32, height: 32, decoration: BoxDecoration(
          color: Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000),
          shape: BoxShape.circle,
          border: Border.all(color: item.properties[key] == hex ? _designerPurple : Colors.grey.shade400, width: item.properties[key] == hex ? 3 : 1),
        )),
      )).toList()),
    ]),
  );
}

class _DesignerReorderPage extends StatelessWidget {
  const _DesignerReorderPage({required this.components, required this.onReorder, required this.iconBuilder, required this.previewBuilder});
  final List<DesignerComponent> components;
  final Future<void> Function(int, int) onReorder;
  final Icon Function(String, {double size}) iconBuilder;
  final Widget Function(DesignerComponent, {bool compact}) previewBuilder;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _designerBackground,
    appBar: AppBar(title: const Text('Reorder Components')),
    body: ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: components.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final component = components[index];
        return Card(
          key: ValueKey(component.id),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: iconBuilder(component.type, size: 30),
            title: Text(component.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: SizedBox(height: 65, child: previewBuilder(component, compact: true)),
            trailing: const Icon(Icons.drag_handle_rounded),
          ),
        );
      },
    ),
  );
}
