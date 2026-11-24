import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'customer_account_page.dart';

// Match the dark, purple-accented native Designer reference supplied by the user.
const _designerPurple = Color(0xFF7650B8);
const _designerBackground = Color(0xFFF7F7FA);
const _designerSurface = Color(0xFFFFFFFF);
const _designerText = Color(0xFF24212B);
const _designerField = Color(0xFFF1EFF5);
const _designerMuted = Color(0xFF77717F);
const _designerBorder = Color(0xFFE4E0EA);

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
    properties['control'] = section['control'] ?? true;
    properties['autoplay'] = section['autoplay'] ?? true;
    properties['autoplay_seconds'] = ((section['interval_ms'] as num?)?.toDouble() ?? 4000) / 1000;
    properties['fade'] = (section['transition'] ?? '') == 'fade';
    properties['view_fraction'] = section['card_width'] ?? 1;
    properties['pause'] = section['pause_on_interaction'] ?? true;
    properties['horizontal'] = section['horizontal'] ?? true;
    properties['link'] = section['tap_url'] ?? '';
    properties['image_url'] = section['image_url'] ?? section['background_image_url'] ?? '';
    properties['source'] = section['source'] ?? 'featured';
    properties['source_id'] = section['category_id'] ?? 0;
    properties['title_font_size'] = section['title_font_size'] ?? 18;
    properties['title_font_weight'] = section['title_font_weight'] ?? 'bold';
    properties['title_text_align'] = section['title_text_align'] ?? 'left';
    properties['title_max_lines'] = section['title_max_lines'] ?? 2;
    properties['countdown_enabled'] = section['countdown_enabled'] ?? false;
    properties['countdown_time'] = section['countdown_time'] ?? '';
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
    var loadedRemote = false;
    if (widget.loadRemoteConfig) {
      try {
        final remote = await ArkCustomerApi(widget.token).request('designer/config');
        if (remote is Map && remote['pages'] is Map) {
          final remotePages = Map<String, dynamic>.from(remote['pages'] as Map);
          for (final page in _pages) {
            final pageKey = _wordpressPageKey(page);
            final pageConfig = remotePages[pageKey];
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
          loadedRemote = true;
        }
      } catch (e) {
        error = 'WordPress Designer config could not be loaded: $e';
      }
    }

    // A device draft is a fallback only. It must never overwrite a newer
    // WordPress configuration just because a local cache exists.
    if (!loadedRemote) {
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

      // Preserve a recoverable local copy before calling the server, but mark
      // it explicitly as pending so the editor never confuses it with a publish.
      await prefs.setString(_storageKey, json);
      try {
        final response = await ArkCustomerApi(widget.token).request('designer/config', method: 'POST', body: {
          'config': data,
          'schema': 'ark-glowhit-designer/v1',
          'status': publish ? 'published' : 'draft',
        });
        if (response is Map) {
          final status = (response['status'] ?? response['state'] ?? '').toString().toLowerCase();
          if (publish && (response['success'] == false || status == 'draft' || status == 'failed')) {
            throw Exception('WordPress returned a non-published configuration response.');
          }
        }
        await prefs.setString('glowhit_published_designer_config', jsonEncode(data));
        await prefs.setString('glowhit_designer_last_server_sync', DateTime.now().toUtc().toIso8601String());
      } catch (e) {
        // The device draft remains recoverable, but do not claim that the server saved it.
        if (mounted) setState(() => error = publish
            ? 'Local draft saved. WordPress did not confirm Publish: $e'
            : 'Local draft saved. WordPress did not confirm the server draft: $e');
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(publish ? 'Published configuration synced to WordPress.' : 'Draft synced to WordPress.'),
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

  Future<void> _addComponent(String type, {String? layout}) async {
    final availableLayouts = _layoutTypes[type]!;
    final selectedLayout = layout != null && availableLayouts.contains(layout)
        ? layout
        : availableLayouts.first;
    final item = DesignerComponent(
      id: _id(),
      type: type,
      title: 'New $type component',
      layout: selectedLayout,
      properties: <String, dynamic>{
        'background_color': '#FFFFFF',
        'title_color': '#241D33',
        'description': '',
        'show_title': true,
        'countdown_enabled': false,
        'countdown_time': '',
        'title_font_size': 18.0,
        'title_font_weight': 'bold',
        'title_text_align': 'left',
        'title_max_lines': 2,
        'padding_top': 12.0, 'padding_bottom': 12.0, 'padding_left': 12.0, 'padding_right': 12.0,
        'margin_top': 0.0, 'margin_bottom': 0.0, 'margin_left': 0.0, 'margin_right': 0.0,
        'height': 180.0, 'width': 1.0, 'max_cross_axis_extent': 300.0,
        'main_axis_spacing': 10.0, 'cross_axis_spacing': 10.0, 'border_radius': 16.0,
        'horizontal': true, 'cross_axis_count': 2, 'cross_aspect_ratio': 1.0,
        'elevation': 1.0, 'fixed_grid_view_count': 2,
        'control': true, 'autoplay': false, 'autoplay_seconds': 4.0,
        'fade': false, 'pause': true, 'dots': true, 'arrows': true,
        'view_fraction': .9,
        'children': <dynamic>[],
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
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .76,
          child: DefaultTabController(
            length: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Text('Add component', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Banner'),
                  Tab(text: 'Category'),
                  Tab(text: 'Product'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [
                  _layoutPickerList(sheetContext, 'Banner'),
                  _layoutPickerList(sheetContext, 'Category'),
                  _layoutPickerList(sheetContext, 'Product'),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _layoutPickerList(BuildContext sheetContext, String type) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: _layoutTypes[type]!.map((layout) => Card(
        elevation: 0,
        child: ListTile(
          leading: _componentIcon(type, size: 28),
          title: Text(layout, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Add $layout to $selectedPage'),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () {
            Navigator.pop(sheetContext);
            _addComponent(type, layout: layout);
          },
        ),
      )).toList(),
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
      query: {'page': '1', 'per_page': '60', 'media_type': 'all'},
    );
    final rows = response is Map && response['items'] is List
        ? (response['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((item) {
            final mime = (item['mime_type'] ?? '').toString();
            return mime.startsWith('image/') || mime.startsWith('video/');
          }).toList()
        : <Map<String, dynamic>>[];
    if (!mounted) return null;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .78,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.perm_media_outlined, color: _designerPurple),
                SizedBox(width: 10),
                Text('WordPress Media Library', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No images or videos found in WordPress Media Library.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                      ),
                      itemCount: rows.length,
                      itemBuilder: (_, index) {
                        final item = rows[index];
                        final mime = (item['mime_type'] ?? '').toString();
                        final isVideo = mime.startsWith('video/');
                        final source = (item['source_url'] ?? '').toString();
                        final preview = (item['thumbnail_url'] ?? '').toString();
                        return InkWell(
                          onTap: () => Navigator.pop(ctx, item),
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(children: [
                              Expanded(
                                child: isVideo
                                    ? Stack(alignment: Alignment.center, children: [
                                        if (preview.isNotEmpty)
                                          Image.network(preview, width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                                        else
                                          const Center(child: Icon(Icons.video_library_outlined, size: 34)),
                                        const CircleAvatar(radius: 15, child: Icon(Icons.play_arrow_rounded, size: 20)),
                                      ])
                                    : source.isEmpty
                                        ? const Icon(Icons.image_not_supported_outlined)
                                        : Image.network(preview.isEmpty ? source : preview, width: double.infinity, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(5),
                                child: Row(children: [
                                  Icon(isVideo ? Icons.videocam_outlined : Icons.image_outlined, size: 13),
                                  const SizedBox(width: 3),
                                  Expanded(child: Text((item['title'] ?? (isVideo ? 'Video' : 'Image')).toString(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ]),
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
    final activeChildren = children.where((child) => child is Map && child['active'] != false).whereType<Map>().toList();
    final firstChild = activeChildren.isNotEmpty ? Map<String, dynamic>.from(activeChildren.first) : <String, dynamic>{};
    final previewImage = (component.properties['image_url'] ?? component.properties['background_image_url'] ?? firstChild['image_url'] ?? firstChild['source_url'] ?? firstChild['url'] ?? '').toString();
    final height = compact ? 92.0 : ((component.properties['height'] as num?)?.toDouble() ?? 160.0).clamp(90.0, 320.0);
    final columns = ((component.properties['cross_axis_count'] as num?)?.toInt() ?? 2).clamp(1, 4);
    final radius = (component.properties['border_radius'] as num?)?.toDouble() ?? 16;
    final childImages = activeChildren.where((child) =>
      (child['type'] ?? 'image') == 'image' &&
      ((child['image_url'] ?? child['source_url'] ?? '').toString().isNotEmpty)).toList();
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
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          if (((component.properties['elevation'] as num?)?.toDouble() ?? 0) > 0)
            BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (component.properties['show_title'] != false && component.title.isNotEmpty)
          Text(
            component.title,
            maxLines: ((component.properties['title_max_lines'] as num?)?.toInt() ?? 2).clamp(1, 4),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: compact ? 12 : ((component.properties['title_font_size'] as num?)?.toDouble() ?? 18),
              fontWeight: (component.properties['title_font_weight'] ?? 'bold') == 'normal'
                  ? FontWeight.normal
                  : (component.properties['title_font_weight'] ?? 'bold') == 'medium' ? FontWeight.w500 : FontWeight.bold,
            ),
          ),
        if (!compact && (component.properties['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(component.properties['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: titleColor.withValues(alpha: .7), fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: component.type == 'Category' || component.type == 'Product'
              ? GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: childImages.isEmpty ? columns : childImages.length.clamp(1, 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: ((component.properties['cross_aspect_ratio'] as num?)?.toDouble() ?? 1).clamp(.5, 2),
                  ),
                  itemBuilder: (_, index) {
                    final image = childImages.isEmpty ? '' : (childImages[index]['image_url'] ?? childImages[index]['source_url']).toString();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(radius.clamp(0, 24)),
                      child: image.isEmpty
                          ? Container(color: titleColor.withValues(alpha: .08),
                              child: Icon(component.type == 'Category' ? Icons.category_outlined : Icons.shopping_bag_outlined,
                                color: titleColor.withValues(alpha: .5)))
                          : Image.network(image, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: titleColor.withValues(alpha: .08),
                                child: const Icon(Icons.broken_image_outlined))),
                    );
                  },
                )
              : childImages.isNotEmpty
                  ? Row(children: childImages.take(component.layout == 'Banner Grid' ? 2 : 1).map((child) {
                      final image = (child['image_url'] ?? child['source_url']).toString();
                      return Expanded(child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radius.clamp(0, 24)),
                          child: Image.network(image, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                        ),
                      ));
                    }).toList())
                  : previewImage.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(radius.clamp(0, 24)),
                          child: Image.network(previewImage, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: titleColor.withValues(alpha: .08),
                              child: const Icon(Icons.broken_image_outlined))),
                        )
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: titleColor.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(radius.clamp(0, 24))),
                          child: Center(child: _componentIcon(component.type, size: compact ? 26 : 36)),
                        ),
        ),
        if (!compact && component.type == 'Banner' && component.layout == 'Banner Slider' &&
            component.properties['dots'] == true && activeChildren.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(activeChildren.length, (index) => Container(
                width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: index == 0 ? _designerPurple : titleColor.withValues(alpha: .25),
                  shape: BoxShape.circle),
              ))),
          ),
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
        backgroundColor: _designerSurface,
        foregroundColor: _designerText,
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
        foregroundColor: const Color(0xFF17121F),
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
                      color: _designerSurface,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: selected ? _designerPurple : _designerBorder, width: selected ? 2 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        _componentIcon(component.type),
                        const SizedBox(width: 8),
                        Expanded(child: Text(component.title, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Switch(value: component.enabled, activeThumbColor: _designerPurple, onChanged: (value) async { setState(() => component.enabled = value); await _persist(); }),
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
      color: _designerSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: _designerBorder)),
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
    final jsonText = const JsonEncoder.withIndent('  ').convert(item.toJson());
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: _designerPurple, brightness: Brightness.light, surface: _designerSurface),
        scaffoldBackgroundColor: _designerBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: _designerSurface,
          foregroundColor: _designerText,
        ),
        cardTheme: const CardThemeData(color: _designerSurface, surfaceTintColor: Colors.transparent),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _designerField,
          labelStyle: const TextStyle(color: _designerMuted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _designerBorder),
          ),
        ),
      ),
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          backgroundColor: _designerBackground,
          appBar: AppBar(
            title: Text(item.type + ' Properties'),
            actions: [
              IconButton(
                tooltip: 'Delete component',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  await widget.onDelete();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              TextButton(
                onPressed: () async {
                  await widget.onSave();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('SAVE'),
              ),
            ],
          ),
          body: Column(
            children: [
              // Keep the live preview visible while the user switches property tabs.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: _designerSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _designerBorder),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LIVE COMPONENT PREVIEW',
                        style: TextStyle(letterSpacing: 1.1, color: _designerPurple, fontWeight: FontWeight.w800, fontSize: 11)),
                      const SizedBox(height: 8),
                      widget.visualBuilder(),
                    ],
                  ),
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: _designerPurple,
                unselectedLabelColor: _designerMuted,
                indicatorColor: _designerPurple,
                tabs: [
                  Tab(text: 'Padding'),
                  Tab(text: 'Margin'),
                  Tab(text: 'Dimension'),
                  Tab(text: 'Settings'),
                  Tab(text: 'Style'),
                  Tab(text: 'Children'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(padding: const EdgeInsets.all(14), children: [
                      _section('Padding', [
                        _slider('Top', 'padding_top'), _slider('Bottom', 'padding_bottom'),
                        _slider('Left', 'padding_left'), _slider('Right', 'padding_right'),
                      ]),
                    ]),
                    ListView(padding: const EdgeInsets.all(14), children: [
                      _section('Margin', [
                        _slider('Top', 'margin_top'), _slider('Bottom', 'margin_bottom'),
                        _slider('Left', 'margin_left'), _slider('Right', 'margin_right'),
                      ]),
                    ]),
                    ListView(padding: const EdgeInsets.all(14), children: [
                      _section('Dimension', [
                        _slider('Height', 'height', min: 40, max: 500),
                        _slider('Width factor', 'width', min: .25, max: 1),
                        _slider('Max cross-axis extent', 'max_cross_axis_extent', min: 80, max: 600),
                        _slider('Main-axis spacing', 'main_axis_spacing', max: 60),
                        _slider('Cross-axis spacing', 'cross_axis_spacing', max: 60),
                        _slider('Border radius', 'border_radius', max: 60),
                        _slider('Cross-axis count', 'cross_axis_count', min: 1, max: 6),
                        _slider('Cross aspect ratio', 'cross_aspect_ratio', min: .4, max: 2.5),
                        _slider('Elevation', 'elevation', max: 20),
                        _slider('Fixed grid view count', 'fixed_grid_view_count', min: 1, max: 10),
                        _switch('Horizontal layout', 'horizontal'),
                      ]),
                    ]),
                    ListView(padding: const EdgeInsets.all(14), children: [
                      _section('Settings', [
                        _switch('Status', 'enabled'),
                        _switch('Show title', 'show_title'),
                        DropdownButtonFormField<String>(
                          initialValue: layouts.contains(item.layout) ? item.layout : layouts.first,
                          decoration: const InputDecoration(labelText: 'Layout type'),
                          items: layouts.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (value) { if (value != null) setState(() => item.layout = value); widget.onChanged(); },
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title'),
                          onChanged: (value) { item.title = value; widget.onChanged(); setState(() {}); }),
                        const SizedBox(height: 12),
                        TextField(controller: _description, maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Description'),
                          onChanged: (value) => _change('description', value)),
                        if (item.type == 'Banner') ...[
                          _switch('Carousel controls', 'control'),
                          _switch('Autoplay', 'autoplay'),
                          if (item.properties['autoplay'] == true) _slider('Autoplay interval (seconds)', 'autoplay_seconds', min: 2, max: 15),
                          _switch('Fade transition', 'fade'),
                          _switch('Pause when touched', 'pause'),
                          _switch('Show dots', 'dots'),
                          _switch('Show arrows', 'arrows'),
                        ],
                        if (item.type == 'Category') _switch('Show all categories', 'show_all_categories'),
                        if (item.type == 'Product') DropdownButtonFormField<String>(
                          initialValue: (item.properties['source'] ?? 'featured').toString(),
                          decoration: const InputDecoration(labelText: 'Product source'),
                          items: const [
                            DropdownMenuItem(value: 'latest', child: Text('Latest')),
                            DropdownMenuItem(value: 'featured', child: Text('Featured')),
                            DropdownMenuItem(value: 'category', child: Text('Category')),
                            DropdownMenuItem(value: 'tag', child: Text('Tag')),
                            DropdownMenuItem(value: 'on_sale', child: Text('On Sale')),
                            DropdownMenuItem(value: 'new_arrival', child: Text('New Arrival')),
                            DropdownMenuItem(value: 'wishlist', child: Text('Wishlist')),
                            DropdownMenuItem(value: 'best_selling', child: Text('Best Selling')),
                            DropdownMenuItem(value: 'top_rated', child: Text('Top Rated')),
                          ],
                          onChanged: (value) { if (value != null) _change('source', value); },
                        ),
                      ]),
                    ]),
                    ListView(padding: const EdgeInsets.all(14), children: [
                      _section('Style', [
                        _colorChoice('Background Color', 'background_color', const ['#FFFFFF', '#F7F7FA', '#F1ECFF', '#E8F6F0', '#FFF0E6', '#202033']),
                        _colorChoice('Title Color', 'title_color', const ['#24212B', '#51408F', '#FFFFFF', '#B23B32', '#16734A']),
                        _colorChoice('Text Color', 'text_color', const ['#24212B', '#FFFFFF', '#7650B8', '#B23B32', '#16734A']),
                        _colorChoice('Text Background Color', 'text_background_color', const ['#FFFFFF', '#F1EFF5', '#202033', '#FFF0E6']),
                        _slider('Font Size', 'title_font_size', min: 8, max: 72),
                        _slider('Letter Spacing', 'letter_spacing', min: 0, max: 20),
                        _slider('Word Spacing', 'word_spacing', min: 0, max: 30),
                        _switch('Italic', 'italic'),
                        TextFormField(
                          initialValue: (item.properties['font_family'] ?? 'Roboto').toString(),
                          decoration: const InputDecoration(labelText: 'Font Family', hintText: 'Roboto, Poppins, Lato…'),
                          onChanged: (value) => _change('font_family', value),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: (item.properties['title_font_weight'] ?? 'normal').toString(),
                          decoration: const InputDecoration(labelText: 'Font weight'),
                          items: const [
                            DropdownMenuItem(value: 'normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'bold', child: Text('Bold')),
                          ],
                          onChanged: (value) { if (value != null) _change('title_font_weight', value); },
                        ),
                        _slider('Maximum title lines', 'title_max_lines', min: 1, max: 5),
                      ]),
                      _section('Live Preview', [widget.visualBuilder()]),
                    ]),
                    ListView(padding: const EdgeInsets.all(14), children: [
                      _section('Children', [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final media = await widget.onChooseMedia();
                              if (media == null) return;
                              final source = (media['source_url'] ?? '').toString();
                              if (source.isEmpty) return;
                              final mime = (media['mime_type'] ?? '').toString();
                              final isVideo = mime.startsWith('video/');
                              final rows = item.properties['children'] is List
                                  ? List<dynamic>.from(item.properties['children'] as List) : <dynamic>[];
                              rows.add({
                                'type': isVideo ? 'video' : 'image',
                                'attachment_id': media['id'],
                                'image_url': isVideo ? '' : source,
                                'video_url': isVideo ? source : '',
                                'source_url': source,
                                'mime_type': mime,
                                'title': (media['title'] ?? 'New').toString(),
                                'alt_text': (media['alt_text'] ?? '').toString(),
                                'link_type': 'in_app', 'link_value': '', 'active': true,
                              });
                              _change('children', rows);
                            },
                            icon: const Icon(Icons.image_outlined), label: const Text('Add image / video'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final controller = TextEditingController();
                              final value = await showDialog<String>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Add text child'),
                                  content: TextField(controller: controller, autofocus: true),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Add')),
                                  ],
                                ),
                              );
                              controller.dispose();
                              if (value == null || value.isEmpty) return;
                              final rows = item.properties['children'] is List
                                  ? List<dynamic>.from(item.properties['children'] as List) : <dynamic>[];
                              rows.add({'type': 'text', 'title': value, 'text': value, 'active': true});
                              _change('children', rows);
                            },
                            icon: const Icon(Icons.text_fields), label: const Text('Add text'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final controller = TextEditingController();
                              final value = await showDialog<String>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Add link child'),
                                  content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'URL or ark:// route')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Add')),
                                  ],
                                ),
                              );
                              controller.dispose();
                              if (value == null || value.isEmpty) return;
                              final rows = item.properties['children'] is List
                                  ? List<dynamic>.from(item.properties['children'] as List) : <dynamic>[];
                              rows.add({'type': 'link', 'title': value, 'link_type': value.startsWith('ark://') ? 'deep_link' : 'url', 'link_value': value, 'active': true});
                              _change('children', rows);
                            },
                            icon: const Icon(Icons.link), label: const Text('Add link'),
                          ),
                        ]),
                        if (item.properties['children'] is List)
                          ...(item.properties['children'] as List).asMap().entries.map((entry) {
                            final child = entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : <String, dynamic>{};
                            final type = (child['type'] ?? 'image').toString();
                            final src = (child['image_url'] ?? child['video_url'] ?? child['source_url'] ?? '').toString();
                            return Card(
                              color: _designerField,
                              child: ListTile(
                                leading: SizedBox(width: 48, height: 48, child: src.isEmpty
                                  ? Icon(type == 'link' ? Icons.link : type == 'text' ? Icons.text_fields : Icons.image)
                                  : Image.network(src, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
                                title: Text((child['title'] ?? 'New').toString()),
                                subtitle: Text(type),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    final rows = List<dynamic>.from(item.properties['children'] as List)..removeAt(entry.key);
                                    _change('children', rows);
                                  },
                                ),
                              ),
                            );
                          }),
                        if (item.properties['children'] is List && (item.properties['children'] as List).length > 1)
                          ReorderableListView(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                            onReorder: (oldIndex, newIndex) {
                              final rows = List<dynamic>.from(item.properties['children'] as List);
                              if (newIndex > oldIndex) newIndex--;
                              final row = rows.removeAt(oldIndex);
                              rows.insert(newIndex, row);
                              _change('children', rows);
                            },
                            children: (item.properties['children'] as List).asMap().entries.map((entry) => ListTile(
                              key: ValueKey('child-order-${item.id}-${entry.key}'),
                              leading: const Icon(Icons.drag_handle),
                              title: Text((entry.value is Map ? (entry.value as Map)['title'] : 'Child')?.toString() ?? 'Child'),
                            )).toList(),
                          ),
                      ]),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
