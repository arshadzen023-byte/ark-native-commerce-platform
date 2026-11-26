import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'customer_account_page.dart';
import 'designer_banner_carousel.dart';

// Match the dark, purple-accented native Designer reference supplied by the user.
const _designerPurple = Color(0xFF7650B8);
const _designerBackground = Color(0xFFF7F7FA);
const _designerSurface = Color(0xFFFFFFFF);
const _designerText = Color(0xFF24212B);
const _designerField = Color(0xFFF1EFF5);
const _designerMuted = Color(0xFF77717F);
const _designerBorder = Color(0xFFE4E0EA);

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
String _friendlyDesignerError(Object error) {
  final raw = error.toString().replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '').trim();
  final message = raw.toLowerCase();
  if (message.contains('socketexception') || message.contains('failed host lookup') || message.contains('no route to host')) return 'Cannot connect to pluginstore.shop. Check your internet and hosting connection.';
  if (message.contains('timeout') || message.contains('timed out')) return 'The server took too long to respond. Please try again.';
  if (message.contains('401') || message.contains('unauthorized')) return 'Designer session expired. Sign in again with the WordPress administrator account.';
  if (message.contains('403') || message.contains('forbidden')) return 'This WordPress account does not have permission to use Designer or upload media.';
  if (message.contains('404') || message.contains('405') || message.contains('no route was found')) return 'Designer API route not found. Confirm ARK Native Commerce Bridge 2.2.4 or newer is active.';
  if (message.contains('413') || message.contains('15 mb')) return 'Image is too large. Choose an image smaller than 15 MB.';
  return raw.isEmpty ? 'Something went wrong. Please try again.' : raw;
}
TextStyle _designerFontStyle(String family, TextStyle base) {
  try {
    return GoogleFonts.getFont(family, textStyle: base);
  } catch (_) {
    return base.copyWith(fontFamily: family);
  }
}

/// Restores published Home components when a legacy native draft contains
/// only a banner. The edited banner replaces the matching live banner, while
/// category and product sections remain visible in Designer.
List<Map<String, dynamic>> restoreLegacyHomeSections(
  List<dynamic> draftSections,
  List<dynamic> publishedSections,
) {
  final draft = draftSections.whereType<Map>()
      .map((value) => Map<String, dynamic>.from(value)).toList();
  final published = publishedSections.whereType<Map>()
      .map((value) => Map<String, dynamic>.from(value)).toList();
  final bannerOnlyDraft = draft.isNotEmpty &&
      draft.length <= 2 &&
      draft.every((section) {
        final type = (section['designer_component_type'] ??
            section['type'] ?? '').toString().toLowerCase();
        return type.startsWith('banner') || type == 'ark_live_slider';
      });
  if (!bannerOnlyDraft || published.length <= draft.length) return draft;

  final merged = List<Map<String, dynamic>>.from(published);
  for (final edited in draft) {
    final id = (edited['id'] ?? '').toString();
    var index = id.isEmpty ? -1 : merged.indexWhere(
      (section) => (section['id'] ?? '').toString() == id,
    );

    // A non-matching component ID normally means this is a new component.
    // Only an old one-component draft with exactly one same-type published
    // candidate is safe to interpret as a legacy edit.
    if (index < 0 && draft.length == 1) {
      final editedType = (edited['designer_component_type'] ??
          edited['type'] ?? '').toString().toLowerCase();
      final candidates = merged.asMap().entries.where((entry) {
        final existingType = (entry.value['designer_component_type'] ??
            entry.value['type'] ?? '').toString().toLowerCase();
        if (editedType.startsWith('banner')) {
          return existingType.startsWith('banner') || existingType == 'ark_live_slider';
        }
        return editedType == existingType;
      }).toList();
      if (candidates.length == 1) index = candidates.single.key;
    }

    if (index >= 0) {
      merged[index] = edited;
    } else {
      // Never overwrite another existing component merely because the types
      // match. New IDs are appended and preserve all other published sections.
      merged.add(edited);
    }
  }
  return merged;
}

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

  Map<String, dynamic> toPublishedSection() {
    final values = Map<String, dynamic>.from(properties);
    // Normalize numeric aliases before sending to WordPress. Its sanitizer
    // stores physical pixel dimensions, spacing and elevation as integers;
    // keeping fractional editor values here causes a false publish mismatch
    // and makes the published layout drift from the Designer preview.
    const integerLayoutKeys = <String>[
      'height', 'height_px', 'max_cross_axis_extent', 'max_width_px',
      'main_axis_spacing', 'cross_axis_spacing', 'item_gap',
      'border_radius', 'corner_radius', 'elevation', 'card_depth',
      'cross_axis_count', 'columns', 'fixed_grid_view_count', 'limit',
      'padding_top', 'padding_bottom', 'padding_left', 'padding_right',
      'margin_top', 'margin_bottom', 'margin_left', 'margin_right',
      'title_bottom_spacing',
    ];
    for (final key in integerLayoutKeys) {
      final value = values[key];
      if (value is num) values[key] = value.round();
    }
    final effectiveElevation = (values['elevation'] ?? values['card_depth'] ?? 1) as num;
    values['elevation'] = effectiveElevation.round();
    values['card_depth'] = effectiveElevation.round();
    final prefix = type.toLowerCase();
    final variant = layout.toLowerCase()
        .replaceFirst('$prefix ', '')
        .replaceAll(' ', '_');
    var designerType = (values['designer_component_type'] ?? '${prefix}_${variant}').toString();
    var storedType = designerType;
    var storedVariant = variant;

    // Keep the native Designer selection aligned with the exact component
    // names and layout keys accepted by ARK App Designer's publish sanitizer.
    if (type == 'Banner') {
      designerType = 'banner_${variant}';
      storedType = designerType; // WordPress converts it to ark_live_slider.
    } else if (type == 'Category') {
      designerType = 'category_${variant}';
      storedType = 'category_grid';
      storedVariant = variant;
    } else if (type == 'Product') {
      designerType = 'product_${variant}';
      storedType = switch (variant) {
        'slider' => 'product_carousel',
        'list' => 'product_list',
        _ => 'product_grid',
      };
      storedVariant = variant;
    } else {
      storedType = (values['original_section_type'] ?? values['type'] ?? designerType).toString();
    }

    final width = (values['width'] as num?)?.toDouble() ?? 1.0;
    final showAllCategories = values['show_all_categories'] == true;
    final rawSource = (values['source'] ?? 'latest').toString();
    final publishedSource = switch (rawSource) {
      'on_sale' => 'sale',
      'new_arrival' => 'latest',
      _ => rawSource,
    };
    final sourceId = (values['source_id'] as num?)?.toInt() ??
        (type == 'Category'
            ? (values['parent_category_id'] as num?)?.toInt()
            : rawSource == 'tag'
                ? (values['tag_id'] as num?)?.toInt()
                : (values['category_id'] as num?)?.toInt()) ?? 0;

    final children = values['children'] is List
        ? (values['children'] as List).whereType<Map>().map((rawChild) {
            final child = Map<String, dynamic>.from(rawChild);
            final kind = (child['type'] ?? 'image').toString().toLowerCase();
            final rawId = child['attachment_id'] ?? child['media_id'] ?? child['id'];
            final attachmentId = rawId is num
                ? rawId.toInt()
                : int.tryParse((rawId ?? '').toString()) ?? 0;
            dynamic rawImage = child['image_url'] ?? child['source_url'] ?? child['url'] ?? child['src'] ?? child['image'] ?? '';
            if (rawImage is Map) rawImage = rawImage['url'] ?? rawImage['src'] ?? '';
            final imageUrl = rawImage.toString().trim();
            final supported = kind == 'image' || kind == 'video';
            if (!supported || (attachmentId < 1 && imageUrl.isEmpty)) return null;
            return <String, dynamic>{
              ...child,
              'type': kind,
              'attachment_id': attachmentId,
              // WordPress SQL slider persistence expects image_url. Normalize
              // source_url/url/src aliases here instead of dropping a selected
              // Media Library image during publish.
              'image_url': kind == 'image' ? imageUrl : '',
              'source_url': imageUrl,
              'title': (child['title'] ?? '').toString().trim(),
              'active': child['active'] != false,
            };
          }).whereType<Map<String, dynamic>>().toList()
        : <dynamic>[];

    return <String, dynamic>{
      ...values,
      'id': id,
      'type': storedType,
      'designer_component_type': designerType,
      'layout_variant': storedVariant,
      'title': title.trim(),
      'visible': enabled && values['visible'] != false,
      'section_background': values['background_color'] ?? values['section_background'] ?? '#FFFFFF',
      'text_color': values['title_color'] ?? values['text_color'] ?? '#24212B',
      'height_px': values['height'] ?? values['height_px'] ?? 180,
      'width': width,
      'width_pct': width * 100,
      'max_width_px': values['max_cross_axis_extent'] ?? values['max_width_px'] ?? 300,
      'main_axis_spacing': values['main_axis_spacing'] ?? 10,
      'cross_axis_spacing': values['cross_axis_spacing'] ?? 10,
      'item_gap': values['cross_axis_spacing'] ?? values['item_gap'] ?? 10,
      'corner_radius': values['border_radius'] ?? values['corner_radius'] ?? 16,
      'columns': values['cross_axis_count'] ?? values['columns'] ?? 2,
      'card_aspect_ratio': values['cross_aspect_ratio'] ?? values['card_aspect_ratio'] ?? 1,
      'card_depth': values['elevation'] ?? values['card_depth'] ?? 1,
      'limit': type == 'Category' && showAllCategories
          ? 100
          : (values['fixed_grid_view_count'] ?? values['limit'] ?? 8),
      'show_arrows': values['control'] == false ? false : (values['arrows'] ?? values['show_arrows'] ?? false),
      'show_dots': values['control'] == false ? false : (values['dots'] ?? values['show_dots'] ?? true),
      'pause_on_interaction': values['pause'] ?? values['pause_on_interaction'] ?? true,
      'transition': values['fade'] == true ? 'fade' : (values['transition'] ?? 'slide'),
      'card_width': values['view_fraction'] ?? values['card_width'] ?? 1,
      'interval_ms': values['interval_ms'] ??
          ((((values['autoplay_seconds'] as num?)?.toDouble() ?? 4) * 1000).round()),
      'category_id': type == 'Category'
          ? (showAllCategories ? 0 : (values['parent_category_id'] ?? values['category_id'] ?? 0))
          : (publishedSource == 'category' ? sourceId : (values['category_id'] ?? 0)),
      'category_layout': type == 'Category' ? storedVariant : (values['category_layout'] ?? ''),
      'tag_id': publishedSource == 'tag' ? sourceId : (values['tag_id'] ?? 0),
      'source': publishedSource,
      'source_id': sourceId,
      'children': children,
    };
  }

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
  List<Map<String, dynamic>> previewProducts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> previewCategories = <Map<String, dynamic>>[];
  String? error;
  Map<String, List<DesignerComponent>> pages = {};
  Map<String, dynamic> templates = {};
  Map<String, dynamic> wordpressConfig = <String, dynamic>{};
  final Map<int, Offset> _componentPointerDown = <int, Offset>{};
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
    final nested = section['properties'] is Map
        ? Map<String, dynamic>.from(section['properties'] as Map)
        : <String, dynamic>{};
    final normalized = <String, dynamic>{...section, ...nested}..remove('properties');
    final rawType = (normalized['designer_component_type'] ?? normalized['type'] ?? '').toString().toLowerCase();
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

    final properties = Map<String, dynamic>.from(normalized);
    if (type == 'Other') properties['original_section_type'] = rawType;
    properties['background_color'] = normalized['section_background'] ?? normalized['background_color'] ?? '#FFFFFF';
    properties['title_color'] = normalized['text_color'] ?? normalized['title_color'] ?? '#241D33';
    properties['height'] = normalized['height_px'] ?? normalized['height'] ?? 180;
    properties['width'] = (normalized['width'] as num?)?.toDouble() ??
        (((normalized['width_pct'] as num?)?.toDouble() ?? 100) / 100);
    properties['max_cross_axis_extent'] = normalized['max_cross_axis_extent'] ?? normalized['max_width_px'] ?? 300;
    properties['main_axis_spacing'] = normalized['main_axis_spacing'] ?? normalized['item_gap'] ?? 10;
    properties['cross_axis_spacing'] = normalized['cross_axis_spacing'] ?? normalized['item_gap'] ?? 10;
    properties['border_radius'] = normalized['corner_radius'] ?? 16;
    properties['cross_axis_count'] = normalized['columns'] ?? 2;
    properties['cross_aspect_ratio'] = normalized['card_aspect_ratio'] ?? 1;
    properties['elevation'] = normalized['card_depth'] ?? 1;
    properties['fixed_grid_view_count'] = normalized['limit'] ?? 12;
    properties['parent_category_id'] = normalized['category_id'] ?? normalized['parent_category_id'] ?? 0;
    properties['show_all_categories'] = (normalized['limit'] as num?)?.toInt() == 100;
    properties['arrows'] = normalized['show_arrows'] ?? false;
    properties['dots'] = normalized['show_dots'] ?? false;
    properties['control'] = normalized['control'] ?? true;
    properties['autoplay'] = normalized['autoplay'] ?? true;
    properties['autoplay_seconds'] = ((normalized['interval_ms'] as num?)?.toDouble() ?? 4000) / 1000;
    properties['fade'] = (normalized['transition'] ?? '') == 'fade';
    properties['view_fraction'] = normalized['card_width'] ?? 1;
    properties['pause'] = normalized['pause_on_interaction'] ?? true;
    properties['horizontal'] = normalized['horizontal'] ?? true;
    properties['link'] = normalized['tap_url'] ?? '';
    properties['image_url'] = normalized['image_url'] ?? normalized['background_image_url'] ?? '';
    properties['source'] = normalized['source'] ?? 'featured';
    properties['source_id'] = normalized['source_id'] ?? normalized['category_id'] ?? normalized['tag_id'] ?? 0;
    properties['title_font_size'] = normalized['title_font_size'] ?? 18;
    properties['title_font_weight'] = normalized['title_font_weight'] ?? 'bold';
    properties['title_text_align'] = normalized['title_text_align'] ?? 'left';
    properties['title_max_lines'] = normalized['title_max_lines'] ?? 2;
    properties['countdown_enabled'] = normalized['countdown_enabled'] ?? false;
    properties['countdown_time'] = normalized['countdown_time'] ?? '';
    properties['children'] = normalized['children'] ?? normalized['slides'] ?? <dynamic>[];

    final sliderKey = (section['slider_key'] ?? '').toString();
    final hasInlineChildren = properties['children'] is List &&
        (properties['children'] as List).isNotEmpty;
    if (sliderKey.isNotEmpty && !hasInlineChildren) {
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
      title: (normalized['title'] ?? 'New component').toString(),
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
          final publishedPages = remote['published_pages'] is Map
              ? Map<String, dynamic>.from(remote['published_pages'] as Map)
              : <String, dynamic>{};
          final effectivePages = Map<String, dynamic>.from(remotePages);
          final draftHome = remotePages['home'] is Map
              ? Map<String, dynamic>.from(remotePages['home'] as Map)
              : <String, dynamic>{};
          final publishedHome = publishedPages['home'] is Map
              ? Map<String, dynamic>.from(publishedPages['home'] as Map)
              : <String, dynamic>{};
          final draftHomeSections = draftHome['sections'] is List
              ? List<dynamic>.from(draftHome['sections'] as List)
              : <dynamic>[];
          final publishedHomeSections = publishedHome['sections'] is List
              ? List<dynamic>.from(publishedHome['sections'] as List)
              : <dynamic>[];
          final restoredHomeSections = remote['native_editor_snapshot'] == true
              ? draftHomeSections
              : restoreLegacyHomeSections(draftHomeSections, publishedHomeSections);
          if (restoredHomeSections.length > draftHomeSections.length) {
            effectivePages['home'] = <String, dynamic>{
              ...publishedHome,
              ...draftHome,
              'sections': restoredHomeSections,
            };
          }
          for (final page in _pages) {
            final pageKey = _wordpressPageKey(page);
            final pageConfig = effectivePages[pageKey];
            final sections = pageConfig is Map && pageConfig['sections'] is List
                ? pageConfig['sections'] as List
                : <dynamic>[];
            wordpressConfig = Map<String, dynamic>.from(remote)
              ..remove('published_pages');
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
    if (widget.loadRemoteConfig) {
      _loadPreviewCatalog();
    }
  }

  Future<void> _loadPreviewCatalog() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://pluginstore.shop/wp-json/wc/store/v1/products?per_page=40')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('https://pluginstore.shop/wp-json/wc/store/v1/products/categories?per_page=40&hide_empty=true')).timeout(const Duration(seconds: 8)),
      ]);
      final products = responses[0].statusCode == 200 ? jsonDecode(responses[0].body) : const [];
      final categories = responses[1].statusCode == 200 ? jsonDecode(responses[1].body) : const [];
      if (!mounted) return;
      setState(() {
        if (products is List) previewProducts = products.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (categories is List) previewCategories = categories.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (_) {
      // Keep the last loaded local/remote component data visible if the store is offline.
    }
  }

  List<DesignerComponent> get currentComponents => pages[selectedPage] ?? <DesignerComponent>[];
  DesignerComponent? get selectedComponent {
    for (final component in currentComponents) {
      if (component.id == selectedId) return component;
    }
    return null;
  }

  Future<void> _persist({bool publish = false}) async {
    if (saving || publishing) return;
    setState(() { saving = !publish; publishing = publish; error = null; });
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final localData = <String, dynamic>{
        'schema': 'ark-glowhit-designer/v1',
        'updated_at': now,
        'pages': pages.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())),
        'templates': templates,
      };
      final localJson = const JsonEncoder.withIndent('  ').convert(localData);
      final publishedConfig = Map<String, dynamic>.from(wordpressConfig);
      final configPages = publishedConfig['pages'] is Map
          ? Map<String, dynamic>.from(publishedConfig['pages'] as Map)
          : <String, dynamic>{};
      for (final page in _pages) {
        final pageKey = _wordpressPageKey(page);
        final existing = configPages[pageKey] is Map
            ? Map<String, dynamic>.from(configPages[pageKey] as Map)
            : <String, dynamic>{'title': page};
        existing['title'] ??= page;
        existing['sections'] = (pages[page] ?? <DesignerComponent>[])
            .map((component) => component.toPublishedSection()).toList();
        configPages[pageKey] = existing;
      }
      publishedConfig['schema_version'] = 3;
      publishedConfig['updated_at'] = now;
      // Marks a complete native snapshot so an intentional deletion/reorder is
      // not later mistaken for a legacy partial draft and merged back.
      publishedConfig['native_editor_snapshot'] = true;
      publishedConfig['pages'] = configPages;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, localJson);
      try {
        final response = await ArkCustomerApi(widget.token).request('designer/config', method: 'POST', body: {
          'config': publishedConfig,
          'status': publish ? 'published' : 'draft',
        });
        if (response is! Map || response['success'] != true) {
          throw Exception('WordPress did not confirm the Designer save.');
        }

        Map<String, dynamic> acceptedConfig = Map<String, dynamic>.from(publishedConfig);
        if (publish) {
          final serverValue = response['published_config'] ??
              response['config'] ??
              (response['data'] is Map ? (response['data'] as Map)['published_config'] : null);
          if (serverValue is! Map || serverValue['pages'] is! Map) {
            throw Exception(
              'WordPress saved the request but returned an incompatible response. '
              'The active ARK Native API Bridge publish endpoint must return the saved Home JSON. '
              'Check that only one ARK Native API Bridge is active and that version 2.2.5 is the active copy.',
            );
          }
          final serverConfig = Map<String, dynamic>.from(serverValue);
          final serverPages = Map<String, dynamic>.from(serverConfig['pages'] as Map);

          // Verify every component ID from the requested snapshot survived the
          // WordPress sanitizer before the UI displays a Publish-success toast.
          for (final page in _pages) {
            final pageKey = _wordpressPageKey(page);
            final requestedPage = configPages[pageKey];
            final savedPage = serverPages[pageKey];
            final requestedSections = requestedPage is Map && requestedPage['sections'] is List
                ? requestedPage['sections'] as List
                : const <dynamic>[];
            final savedSections = savedPage is Map && savedPage['sections'] is List
                ? savedPage['sections'] as List
                : const <dynamic>[];
            final savedIds = savedSections.whereType<Map>()
                .map((section) => (section['id'] ?? '').toString()).toSet();
            final missingIds = requestedSections.whereType<Map>()
                .map((section) => (section['id'] ?? '').toString())
                .where((id) => id.isNotEmpty && !savedIds.contains(id))
                .toList();
            if (missingIds.isNotEmpty) {
              throw Exception('WordPress dropped ' + missingIds.length.toString() +
                  ' component(s) from page "' + page + '" while publishing. Missing IDs: ' +
                  missingIds.join(', '));
            }
          }
          // WordPress sanitizes legacy Banner sections to ark_live_slider and
          // may preserve an older partial editor draft. Keep the exact public
          // server document, but restore its published Home sections into the
          // native editor snapshot when the editor draft is only a partial list.
          final publishedPages = serverConfig['pages'] is Map
              ? Map<String, dynamic>.from(serverConfig['pages'] as Map)
              : <String, dynamic>{};
          final publishedHome = publishedPages['home'] is Map
              ? Map<String, dynamic>.from(publishedPages['home'] as Map)
              : <String, dynamic>{};
          final publishedHomeSections = publishedHome['sections'] is List
              ? List<dynamic>.from(publishedHome['sections'] as List)
              : <dynamic>[];
          final currentHomeSections = configPages['home'] is Map &&
                  (configPages['home'] as Map)['sections'] is List
              ? List<dynamic>.from((configPages['home'] as Map)['sections'] as List)
              : <dynamic>[];
          if (publishedHomeSections.isEmpty && currentHomeSections.isNotEmpty) {
            throw Exception('WordPress published Home contains no sections although the editor submitted components. Check the Designer publish sanitizer.');
          }
          final publishedHomeIds = publishedHomeSections.whereType<Map>()
              .map((section) => (section['id'] ?? '').toString()).toSet();
          final submittedHomeIds = currentHomeSections.whereType<Map>()
              .map((section) => (section['id'] ?? '').toString()).toSet();
          if (submittedHomeIds.isNotEmpty &&
              !submittedHomeIds.every(publishedHomeIds.contains)) {
            throw Exception('WordPress published Home did not retain every submitted component ID.');
          }
          // Verify the layout/style values that must survive WordPress
          // sanitization. This prevents a green Publish result when the server
          // silently resets a component's dimensions or visual properties.
          const propertyKeys = <String>[
            'width', 'width_pct', 'height', 'height_px', 'min_height_px',
            'max_width_px', 'max_cross_axis_extent', 'main_axis_spacing',
            'cross_axis_spacing', 'item_gap', 'corner_radius', 'border_radius',
            'columns', 'cross_axis_count', 'cross_aspect_ratio',
            'card_aspect_ratio', 'card_depth', 'elevation', 'card_image_fit',
            'margin_top', 'margin_bottom', 'margin_left', 'margin_right',
            'padding_top', 'padding_bottom', 'padding_left', 'padding_right',
            'title_bottom_spacing',
            'section_background', 'text_color', 'title_color', 'title_background_color',
            'card_background', 'background_image_url', 'background_image_fit',
            'background_image_alignment', 'background_image_position',
            'background_position', 'background_size', 'background_repeat',
            'font_family', 'title_font_size', 'title_font_weight', 'italic',
            'letter_spacing', 'word_spacing', 'text_style',
          ];
          // Compatibility aliases (for example item_gap) may be normalized by
          // WordPress from their canonical field. Verify canonical design
          // properties and their aliases against the same effective value.
          const aliasGroups = <String, List<String>>{
            'main_axis_spacing': ['main_axis_spacing'],
            'cross_axis_spacing': ['cross_axis_spacing', 'item_gap'],
            'height_px': ['height_px', 'height'],
            'max_width_px': ['max_width_px', 'max_cross_axis_extent'],
            'corner_radius': ['corner_radius', 'border_radius'],
            'columns': ['columns', 'cross_axis_count'],
            'card_aspect_ratio': ['card_aspect_ratio', 'cross_aspect_ratio'],
            'card_depth': ['card_depth', 'elevation'],
            'width': ['width', 'width_pct'],
          };
          for (final page in _pages) {
            final pageKey = _wordpressPageKey(page);
            final requestedPage = configPages[pageKey];
            final savedPage = serverPages[pageKey];
            final requestedSections = requestedPage is Map && requestedPage['sections'] is List
                ? requestedPage['sections'] as List
                : const <dynamic>[];
            final savedSections = savedPage is Map && savedPage['sections'] is List
                ? savedPage['sections'] as List
                : const <dynamic>[];
            final savedById = <String, Map>{};
            for (final section in savedSections.whereType<Map>()) {
              savedById[(section['id'] ?? '').toString()] = section;
            }
            for (final requested in requestedSections.whereType<Map>()) {
              final id = (requested['id'] ?? '').toString();
              final saved = savedById[id];
              if (saved == null) continue;
              final requestedProperties = requested['properties'] is Map
                  ? Map<String, dynamic>.from(requested['properties'] as Map)
                  : <String, dynamic>{};
              final savedProperties = saved['properties'] is Map
                  ? Map<String, dynamic>.from(saved['properties'] as Map)
                  : <String, dynamic>{};
              for (final key in propertyKeys) {
                if (!requested.containsKey(key) && !requestedProperties.containsKey(key)) continue;
                final before = requested[key] ?? requestedProperties[key];
                final after = saved[key] ?? savedProperties[key];
                if (before == null && after == null) continue;
                if (after == null) {
                  throw Exception('WordPress did not preserve "$key" for component "' +
                      (requested['title'] ?? id).toString() + '" on page "' + page + '".');
                }
                final numEqual = before is num && after is num
                    ? (before.toDouble() - after.toDouble()).abs() < 0.01
                    : false;
                // These aliases are redundant fields that the WordPress
                // sanitizer may round or regenerate. They must not veto a
                // publish when the canonical value is unchanged.
                final isAlias = aliasGroups.values.any(
                  (aliases) => aliases.skip(1).contains(key),
                );
                final effectiveBefore = before is num ? before.toDouble() : before;
                final effectiveAfter = after is num ? after.toDouble() : after;
                final equal = numEqual || jsonEncode(effectiveBefore) == jsonEncode(effectiveAfter);
                if (!equal && !isAlias) {
                  throw Exception('WordPress changed "$key" for component "' +
                      (requested['title'] ?? id).toString() + '" on page "' + page +
                      '" (Designer: ' + before.toString() + ', published: ' + after.toString() + ').');
                }
              }
            }
          }

          acceptedConfig = serverConfig;
          await prefs.setString('glowhit_published_designer_config', jsonEncode(acceptedConfig));
        }
        wordpressConfig = acceptedConfig;
        await prefs.setString('glowhit_designer_last_server_sync', DateTime.now().toUtc().toIso8601String());
      } catch (e) {
        // The device draft remains recoverable, but do not claim that the server saved it.
        if (mounted) {
          final message = publish
              ? 'Local draft saved, but Publish was not confirmed: ' + _friendlyDesignerError(e)
              : 'Local draft saved, but server sync was not confirmed: ' + _friendlyDesignerError(e);
          setState(() => error = message);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
          ));
        }
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(publish ? 'Published configuration synced to WordPress.' : 'Draft synced to WordPress.'),
      ));
    } catch (e) {
      if (mounted) {
        final message = _friendlyDesignerError(e);
        setState(() => error = message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
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
        'section_background': '#FFFFFF',
        'text_color': '#241D33',
        'height_px': 180.0,
        'width_pct': 100.0,
        'max_width_px': 300.0,
        'item_gap': 10.0,
        'corner_radius': 16.0,
        'columns': 2,
        'card_aspect_ratio': 1.0,
        'card_depth': 1.0,
        'limit': 2,
        'visible': true,
        'show_arrows': true,
        'show_dots': true,
        'pause_on_interaction': true,
      },
    );
    final variant = selectedLayout.toLowerCase()
        .replaceFirst('${type.toLowerCase()} ', '')
        .replaceAll(' ', '_');
    item.properties['designer_component_type'] = '${type.toLowerCase()}_${variant}';
    item.properties['layout_variant'] = variant;
    if (type == 'Category') item.properties['category_layout'] = variant;
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

  Future<Map<String, dynamic>?> _uploadGalleryMedia() async {
    try {
      final picked = await ImagePicker().pickMedia();
      if (picked == null) return null;
      final mime = (picked.mimeType ?? '').toLowerCase();
      if (mime.isNotEmpty && !mime.startsWith('image/')) {
        throw Exception('Please select an image file (JPG, PNG, WEBP or GIF).');
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024) {
        throw Exception('Image must be smaller than 15 MB.');
      }
      final base = Uri.parse('https://pluginstore.shop');
      Future<http.Response> send(Uri uri) async {
        final request = http.MultipartRequest('POST', uri)
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer ${widget.token}'
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: picked.name,
          ));
        final streamed = await request.send().timeout(const Duration(seconds: 60));
        return http.Response.fromStream(streamed);
      }
      var response = await send(base.resolve('wp-json/ark-native/v1/designer/media'));
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await send(base.replace(
          path: '/',
          queryParameters: {'rest_route': '/ark-native/v1/designer/media'},
        ));
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception('WordPress returned an invalid upload response (HTTP ${response.statusCode}).');
      }
      if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map) {
        final message = decoded is Map ? (decoded['message'] ?? decoded['code']) : null;
        throw Exception(message?.toString() ?? 'Image upload failed (HTTP ${response.statusCode}).');
      }
      final media = Map<String, dynamic>.from(decoded);
      media['source_url'] = (media['source_url'] ?? media['url'] ?? '').toString();
      media['mime_type'] = (media['mime_type'] ?? mime).toString();
      if (media['source_url'].toString().isEmpty) {
        throw Exception('WordPress uploaded the file but returned no Media URL.');
      }
      return media;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery upload failed: ' + _friendlyDesignerError(error))),
        );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> _chooseMedia() async {
    try {
      final response = await ArkCustomerApi(widget.token).request(
        'designer/media',
        query: {'page': '1', 'per_page': '60'},
      );
      if (!mounted) return null;
      final rawItems = response is Map
          ? (response['items'] ?? response['media'] ?? response['data'])
          : response;
      if (rawItems is! List) {
        final message = response is Map
            ? (response['message'] ?? response['code'] ?? 'WordPress returned an invalid Media Library response.')
            : 'WordPress returned an invalid Media Library response.';
        throw FormatException(message.toString());
      }
      final rows = rawItems
          .whereType<Map>()
          .map((entry) {
            final item = Map<String, dynamic>.from(entry);
            final guid = item['guid'] is Map ? (item['guid'] as Map)['rendered'] : null;
            item['source_url'] = (item['source_url'] ?? item['url'] ?? guid ?? '').toString();
            final mediaDetails = item['media_details'] is Map
                ? Map<String, dynamic>.from(item['media_details'] as Map)
                : <String, dynamic>{};
            final mediaSizes = mediaDetails['sizes'] is Map
                ? Map<String, dynamic>.from(mediaDetails['sizes'] as Map)
                : <String, dynamic>{};
            final thumbnailData = mediaSizes['thumbnail'] is Map
                ? Map<String, dynamic>.from(mediaSizes['thumbnail'] as Map)
                : <String, dynamic>{};
            item['thumbnail_url'] = (item['thumbnail_url'] ??
                thumbnailData['source_url'] ?? item['source_url']).toString();
            item['mime_type'] = (item['mime_type'] ?? item['mime'] ?? 'image/jpeg').toString();
            item['alt_text'] = (item['alt_text'] ?? item['alt'] ?? '').toString();
            return item;
          })
          .where((entry) => (entry['mime_type'] ?? '').toString().startsWith('image/'))
          .where((entry) => (entry['source_url'] ?? '').toString().trim().isNotEmpty)
          .toList();
      final searchController = TextEditingController();
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = rows.where((entry) {
            final title = (entry['title'] ?? '').toString().toLowerCase();
            final url = (entry['source_url'] ?? '').toString().toLowerCase();
            return query.isEmpty || title.contains(query) || url.contains(query);
          }).toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * .82,
              child: Column(children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    Icon(Icons.perm_media_outlined, color: _designerPurple),
                    SizedBox(width: 10),
                    Text('WordPress Media Library', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => refresh(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search images',
                      filled: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Upload image from phone Gallery'),
                      onPressed: () async {
                        final uploaded = await _uploadGalleryMedia();
                        if (uploaded != null && ctx.mounted) Navigator.pop(ctx, uploaded);
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No matching images found.'))
                      : GridView.builder(
                          key: const ValueKey('designer-media-library-grid'),
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final entry = filtered[index];
                            final source = (entry['source_url'] ?? '').toString();
                            final preview = (entry['thumbnail_url'] ?? '').toString();
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, entry),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(children: [
                                  Expanded(
                                    child: Image.network(
                                      preview.isEmpty ? source : preview,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const ColoredBox(
                                        color: _designerField,
                                        child: Center(child: Icon(Icons.broken_image_outlined)),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Text(
                                      (entry['title'] ?? 'Image').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          );
        }),
      );
      searchController.dispose();
      return selected;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load WordPress Media Library: ' + _friendlyDesignerError(error))),
        );
      }
      return null;
    }
  }


  Widget _componentVisual(DesignerComponent component, {bool compact = false, VoidCallback? onEdit}) {
    final imageCacheWidth = (MediaQuery.of(context).size.width *
        MediaQuery.of(context).devicePixelRatio).round().clamp(320, 2048);
    final properties = component.properties;
    final bg = _color((properties['background_color'] ?? properties['section_background'] ?? '#FFFFFF').toString());
    final titleColor = _color((properties['title_color'] ?? properties['text_color'] ?? '#24212B').toString());
    final rawChildren = properties['children'] is List ? properties['children'] as List : const <dynamic>[];
    final activeChildren = rawChildren.where((child) => child is Map && child['active'] != false).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final imageChildren = activeChildren.where((child) {
      final kind = (child['type'] ?? 'image').toString();
      final url = (child['image_url'] ?? child['source_url'] ?? child['url'] ?? '').toString();
      return (kind == 'image' || kind == 'video') && url.isNotEmpty;
    }).toList();
    final fallbackImage = (properties['image_url'] ?? properties['background_image_url'] ?? '').toString();
    if (imageChildren.isEmpty && fallbackImage.isNotEmpty) {
      imageChildren.add({'image_url': fallbackImage, 'title': component.title, 'active': true});
    }
    final height = ((properties['height'] ?? properties['height_px']) as num?)?.toDouble() ?? 180;
    final columns = ((properties['cross_axis_count'] ?? properties['columns']) as num?)?.toInt() ?? 2;
    final gap = ((properties['cross_axis_spacing'] ?? properties['item_gap']) as num?)?.toDouble() ?? 8;
    final mainGap = ((properties['main_axis_spacing'] ?? properties['item_gap']) as num?)?.toDouble() ?? gap;
    final radius = ((properties['border_radius'] ?? properties['corner_radius']) as num?)?.toDouble() ?? 14;
    // Dimension values describe child items, never the outer section/card.
    final childWidthFactor = ((properties['width'] as num?)?.toDouble() ?? 1).clamp(.2, 1.0).toDouble();
    final maxChildWidth = ((properties['max_cross_axis_extent'] ?? properties['max_width_px']) as num?)?.toDouble() ?? (component.type == 'Category' ? 180 : component.type == 'Product' ? 174 : 600);
    final margin = EdgeInsets.fromLTRB(
      ((properties['margin_left'] as num?)?.toDouble() ?? 0),
      ((properties['margin_top'] as num?)?.toDouble() ?? 0),
      ((properties['margin_right'] as num?)?.toDouble() ?? 0),
      ((properties['margin_bottom'] as num?)?.toDouble() ?? 0),
    );
    final padding = EdgeInsets.fromLTRB(
      ((properties['padding_left'] as num?)?.toDouble() ?? 12),
      ((properties['padding_top'] as num?)?.toDouble() ?? 12),
      ((properties['padding_right'] as num?)?.toDouble() ?? 12),
      ((properties['padding_bottom'] as num?)?.toDouble() ?? 12),
    );
    final isBanner = component.type == 'Banner';
    final isProduct = component.type == 'Product';
    final isCategory = component.type == 'Category';
    final layout = component.layout.toLowerCase();
    final isSlider = layout.contains('slider');
    final isScroll = layout.contains('scroll') || isSlider;
    final isList = layout.contains('list');
    final previewLimit = ((properties['fixed_grid_view_count'] as num?)?.toInt() ?? 8).clamp(1, 40).toInt();
    final productSource = (properties['source'] ?? 'latest').toString();
    final sourceId = ((properties['source_id'] ?? properties['category_id'] ?? properties['tag_id']) as num?)?.toInt() ?? 0;
    final productItems = previewProducts.where((product) {
      if (productSource == 'featured') return product['is_featured'] == true;
      if (productSource == 'on_sale' || productSource == 'sale') return product['on_sale'] == true;
      if (productSource == 'category' && sourceId > 0) {
        final ids = product['categories'] is List
            ? (product['categories'] as List).whereType<Map>().map((entry) => (entry['id'] as num?)?.toInt()).toList()
            : <int?>[];
        return ids.contains(sourceId);
      }
      if (productSource == 'tag' && sourceId > 0) {
        final ids = product['tags'] is List
            ? (product['tags'] as List).whereType<Map>().map((entry) => (entry['id'] as num?)?.toInt()).toList()
            : <int?>[];
        return ids.contains(sourceId);
      }
      if (productSource == 'wishlist') return false;
      return true;
    }).toList();
    // Never substitute all products when a selected source/filter has no
    // matches; the Designer preview must show the same selection as Home.
    final visibleProductItems = productItems.take(previewLimit).toList();
    final parentCategoryId = ((properties['parent_category_id'] ?? properties['category_id']) as num?)?.toInt() ?? 0;
    final categoryItems = previewCategories.where((category) {
      if (properties['show_all_categories'] == true || parentCategoryId <= 0) return true;
      return (category['parent'] as num?)?.toInt() == parentCategoryId;
    }).take(previewLimit).toList();

    Widget imageTile(Map<String, dynamic> child, {double? tileWidth}) {
      final url = (child['image_url'] ?? child['source_url'] ?? child['url'] ?? '').toString();
      final image = url.isEmpty
          ? Container(color: titleColor.withValues(alpha: .08), child: const Icon(Icons.image_outlined))
          : Image.network(url, width: double.infinity, height: double.infinity, fit: BoxFit.cover, cacheWidth: imageCacheWidth, gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(color: titleColor.withValues(alpha: .08), child: const Icon(Icons.broken_image_outlined)));
      return SizedBox(
        width: tileWidth,
        height: height.clamp(40, 500).toDouble(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius.clamp(0, 32).toDouble()),
          child: Stack(fit: StackFit.expand, children: [
            image,
            if ((child['title'] ?? '').toString().isNotEmpty)
              Align(alignment: Alignment.bottomCenter, child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.black.withValues(alpha: .52),
                child: Text(child['title'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              )),
          ]),
        ),
      );
    }

    Widget productTile(Map<String, dynamic> product, {double? tileWidth}) {
      final images = product['images'] is List ? product['images'] as List : const [];
      final first = images.isNotEmpty && images.first is Map ? Map<String, dynamic>.from(images.first as Map) : <String, dynamic>{};
      final imageUrl = (first['thumbnail'] ?? first['src'] ?? '').toString();
      final name = (product['name'] ?? 'Product').toString();
      final prices = product['prices'] is Map ? Map<String, dynamic>.from(product['prices'] as Map) : <String, dynamic>{};
      final minor = (prices['currency_minor_unit'] as num?)?.toInt() ?? 2;
      final raw = double.tryParse((prices['price'] ?? '').toString()) ?? 0;
      final divisor = minor == 0 ? 1 : (minor == 1 ? 10 : 100);
      final amount = prices.isEmpty ? (product['price_html'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '') :
        '${prices['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(minor)}';
      return SizedBox(
        width: tileWidth,
        height: height.clamp(40, 500).toDouble(),
        child: Card(
          margin: EdgeInsets.zero,
          color: _designerSurface,
          clipBehavior: Clip.antiAlias,
          elevation: ((properties['elevation'] as num?)?.toDouble() ?? 1).clamp(0, 12).toDouble(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.clamp(0, 28).toDouble())),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SizedBox(width: double.infinity,
              child: imageUrl.isEmpty
                ? Container(color: _designerField, child: const Icon(Icons.shopping_bag_outlined, size: 34))
                : Image.network(imageUrl, fit: BoxFit.contain, cacheWidth: imageCacheWidth, gaplessPlayback: true, errorBuilder: (_, __, ___) => Container(color: _designerField, child: const Icon(Icons.broken_image_outlined))))),
            Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF24212B), fontSize: 12, fontWeight: FontWeight.w600))),
            Padding(padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
              child: Text(amount, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _designerPurple, fontSize: 13, fontWeight: FontWeight.w800))),
          ]),
        ),
      );
    }

    Widget categoryTile(Map<String, dynamic> category, {double? tileWidth}) {
      final image = category['image'] is Map ? Map<String, dynamic>.from(category['image'] as Map) : <String, dynamic>{};
      final url = (image['src'] ?? '').toString();
      return SizedBox(
        width: tileWidth,
        height: height.clamp(40, 500).toDouble(),
        child: Card(
          margin: EdgeInsets.zero,
          color: _designerSurface,
          clipBehavior: Clip.antiAlias,
          elevation: ((properties['elevation'] as num?)?.toDouble() ?? 1).clamp(0, 12).toDouble(),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.clamp(0, 28).toDouble())),
          child: Column(children: [
            Expanded(child: SizedBox(width: double.infinity, child: url.isEmpty
              ? const Icon(Icons.category_outlined, size: 32)
              : Image.network(url, fit: BoxFit.cover, cacheWidth: imageCacheWidth, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined)))),
            Padding(padding: const EdgeInsets.all(7), child: Text((category['name'] ?? 'Category').toString(),
              maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
        ),
      );
    }

    Widget content;
    if (isBanner) {
      final slides = imageChildren.isEmpty ? <Map<String, dynamic>>[{'image_url': '', 'title': ''}] : imageChildren;
      if (isSlider) {
        content = LayoutBuilder(builder: (context, constraints) {
          final childWidth = (constraints.maxWidth * childWidthFactor).clamp(40, maxChildWidth).toDouble();
          return Align(alignment: Alignment.centerLeft, child: SizedBox(
            width: childWidth,
            height: height.clamp(40, 500).toDouble(),
            child: ArkDesignerBannerCarousel(
          slides: slides,
          height: height.clamp(40, 500).toDouble(),
          radius: radius,
          autoplay: properties['autoplay'] != false,
          interval: Duration(milliseconds: (((properties['autoplay_seconds'] as num?)?.toDouble() ?? 4) * 1000).round().clamp(1000, 30000).toInt()),
          pauseOnInteraction: properties['pause'] != false,
          showDots: properties['dots'] != false && properties['control'] != false,
          showArrows: properties['arrows'] == true && properties['control'] != false,
          fade: properties['fade'] == true,
          viewFraction: ((properties['view_fraction'] as num?)?.toDouble() ?? .9).clamp(.4, 1).toDouble(),
          elevation: ((properties['elevation'] as num?)?.toDouble() ?? 1).clamp(0, 20).toDouble(),
          onTap: onEdit,
        )));
        });
      } else if (isScroll) {
        content = LayoutBuilder(builder: (context, constraints) => SizedBox(height: height.clamp(40, 500).toDouble(), child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: slides.length,
          separatorBuilder: (_, __) => properties['horizontal'] == false ? SizedBox(height: mainGap) : SizedBox(width: gap),
          itemBuilder: (_, index) => imageTile(slides[index], tileWidth: (constraints.maxWidth * childWidthFactor).clamp(40, maxChildWidth).toDouble()),
        )));
      } else if (isList) {
        content = LayoutBuilder(builder: (context, constraints) => SizedBox(
          height: (height.clamp(40, 500) * slides.length +
              mainGap * (slides.length > 0 ? slides.length - 1 : 0)).clamp(40, 7200).toDouble(),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slides.length,
            separatorBuilder: (_, __) => SizedBox(height: mainGap),
            itemBuilder: (_, index) => Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: constraints.maxWidth * childWidthFactor,
                height: height.clamp(40, 500).toDouble(),
                child: imageTile(slides[index]),
              ),
            ),
          ),
        ));
      } else {
        final shown = slides.take(previewLimit).toList();
        final bannerAspect = ((properties['cross_aspect_ratio'] as num?)?.toDouble() ?? 1.2).clamp(.4, 3).toDouble();
        final bannerChildHeight = (height * (1.2 / bannerAspect)).clamp(40, 600).toDouble();
        content = GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shown.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns.clamp(1, 6).toInt(),
            crossAxisSpacing: gap.toDouble(),
            mainAxisSpacing: mainGap.toDouble(),
            mainAxisExtent: bannerChildHeight,
          ),
          itemBuilder: (_, index) => LayoutBuilder(
            builder: (context, constraints) {
              final childWidth = constraints.maxWidth * childWidthFactor;
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: childWidth,
                  height: bannerChildHeight,
                  child: imageTile(shown[index]),
                ),
              );
            },
          ),
        );
      }
    } else if (isProduct || isCategory) {
      final count = isProduct ? visibleProductItems.length : categoryItems.length;
      final cardHeight = height.clamp(40, 500).toDouble();
      final gridAspect = ((properties['cross_aspect_ratio'] ?? properties['card_aspect_ratio']) as num?)?.toDouble() ?? (isProduct ? .66 : .9);
      final gridChildHeight = (cardHeight * ((isProduct ? .66 : .9) / gridAspect)).clamp(40, 700).toDouble();
      final cardWidth = ((properties['max_cross_axis_extent'] ?? properties['max_width_px']) as num?)?.toDouble() ?? (isProduct ? 174 : 180);
      Widget tile(int index, {double? width}) => isProduct
          ? productTile(visibleProductItems[index], tileWidth: width)
          : categoryTile(categoryItems[index], tileWidth: width);
      Widget dimensionedGridChild(int index) => LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : cardWidth;
          final childWidth = (cellWidth * childWidthFactor)
              .clamp(40, cardWidth)
              .toDouble();
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: childWidth,
              height: gridChildHeight,
              child: tile(index, width: childWidth),
            ),
          );
        },
      );
      if (count == 0) {
        content = SizedBox(height: cardHeight, child: Center(child: Text(
          isProduct ? 'Loading live products…' : 'Loading live categories…',
          style: TextStyle(color: titleColor.withValues(alpha: .7), fontSize: 12))));
      } else if (isScroll) {
        content = SizedBox(height: cardHeight, child: ListView.separated(
          scrollDirection: properties['horizontal'] == false ? Axis.vertical : Axis.horizontal,
          itemCount: count,
          separatorBuilder: (_, __) => properties['horizontal'] == false ? SizedBox(height: mainGap) : SizedBox(width: gap),
          itemBuilder: (_, index) => tile(index, width: cardWidth * childWidthFactor),
        ));
      } else if (isList) {
        content = SizedBox(height: (cardHeight * count + mainGap * (count > 0 ? count - 1 : 0)).clamp(cardHeight, 900).toDouble(), child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, __) => SizedBox(height: mainGap),
          itemBuilder: (_, index) => Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: cardWidth * childWidthFactor,
              height: cardHeight,
              child: tile(index, width: cardWidth * childWidthFactor),
            ),
          ),
        ));
      } else {
        final visibleCount = count.clamp(1, 40).toInt();
        content = SizedBox(height: (gridChildHeight * ((visibleCount / columns.clamp(1, 6).toInt()).ceil()) + mainGap * 2).clamp(gridChildHeight, 4000).toDouble(), 
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleCount,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns.clamp(1, 6).toInt(),
              crossAxisSpacing: gap.toDouble(),
              mainAxisSpacing: mainGap.toDouble(),
              mainAxisExtent: gridChildHeight,
            ),
            itemBuilder: (_, index) => dimensionedGridChild(index),
          ));
      }
    } else {
      content = SizedBox(height: height.clamp(90, 500).toDouble(), child: imageChildren.isNotEmpty
        ? imageTile(imageChildren.first)
        : Center(child: _componentIcon(component.type, size: 34)));
    }

    final title = (properties['show_title'] == false) ? '' : component.title;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onEdit == null || (isBanner && isSlider) ? null : (event) {
        _componentPointerDown[event.pointer] = event.position;
      },
      onPointerUp: onEdit == null || (isBanner && isSlider) ? null : (event) {
        final start = _componentPointerDown.remove(event.pointer);
        if (start != null && (event.position - start).distance < 12) {
          onEdit();
        }
      },
      onPointerCancel: (event) => _componentPointerDown.remove(event.pointer),
      child: Opacity(
        opacity: component.enabled ? 1 : .38,
        child: LayoutBuilder(builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 24;
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: (availableWidth - margin.horizontal).clamp(0, availableWidth).toDouble(),
            margin: margin,
            padding: padding,
            decoration: BoxDecoration(
              color: (properties['background_image_url'] ?? '').toString().isNotEmpty
                  ? Colors.transparent
                  : bg,
              image: (properties['background_image_url'] ?? '').toString().isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(properties['background_image_url'].toString()),
                      fit: _designerBackgroundFit(properties['background_image_fit']),
                      alignment: _designerBackgroundAlignment(properties['background_image_alignment']),
                    )
                  : null,
              // Section shell remains neutral; radius and elevation belong to child cards.
              borderRadius: BorderRadius.zero,
              boxShadow: const [],
            ),
            // Keep the component at its authored dimensions. When the editor's
            // available viewport is shorter than the component, scroll the preview
            // instead of shrinking it or overflowing the RenderFlex.
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: ((properties['title_bottom_spacing'] as num?)
                                ?.toDouble() ??
                            8),
                      ),
                      child: GestureDetector(
                        onTap: isBanner && isSlider ? onEdit : null,
                        child: Text(
                          title,
                          maxLines: ((properties['title_max_lines'] as num?)
                                  ?.toInt() ??
                              2)
                              .clamp(1, 4)
                              .toInt(),
                          overflow: TextOverflow.ellipsis,
                          textAlign: (properties['title_text_align'] ?? 'left') ==
                                  'center'
                              ? TextAlign.center
                              : (properties['title_text_align'] ?? 'left') ==
                                      'right'
                                  ? TextAlign.right
                                  : TextAlign.left,
                          style: _designerFontStyle(
                            (properties['font_family'] ?? 'Roboto').toString(),
                            TextStyle(
                            color: titleColor,
                            backgroundColor: _color((properties['title_background_color'] ?? '#00000000').toString()),
                            fontSize: compact
                                ? 12
                                : ((properties['title_font_size'] as num?)
                                        ?.toDouble() ??
                                    18),
                            fontWeight:
                                (properties['title_font_weight'] ?? 'bold') ==
                                        'normal'
                                    ? FontWeight.normal
                                    : (properties['title_font_weight'] ??
                                                'bold') ==
                                            'medium'
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                            fontFamily:
                                (properties['font_family'] ?? 'Roboto')
                                    .toString(),
                            fontStyle: properties['italic'] == true
                                ? FontStyle.italic
                                : FontStyle.normal,
                            letterSpacing:
                                (properties['letter_spacing'] as num?)
                                        ?.toDouble() ??
                                    0,
                            wordSpacing:
                                (properties['word_spacing'] as num?)
                                        ?.toDouble() ??
                                    0,
                          )),
                        ),
                      ),
                    ),
                  content,
                ],
              ),
            ),
          ),
        );
        }),
      ),
    );
  }

  Color _color(String input) {
    if (input.toLowerCase() == 'transparent') return Colors.transparent;
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

  Future<void> _openDesignerSettings() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => _DesignerSettingsPage(
      saving: saving,
      publishing: publishing,
      onSaveDraft: () => _persist(),
      onPublish: () => _persist(publish: true),
    )));
  }

  Widget _designerMenu() => PopupMenuButton<String>(
    icon: const Icon(Icons.menu_rounded),
    tooltip: 'Designer menu',
    onSelected: (value) {
      if (value == 'reorder') _openReorder();
      if (value == 'templates') _openTemplates();
      if (value == 'my_templates') _openMyTemplates();
      if (value == 'settings') _openDesignerSettings();
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'reorder', child: ListTile(leading: Icon(Icons.reorder), title: Text('Reorder Components'), dense: true)),
      PopupMenuItem(value: 'templates', child: ListTile(leading: Icon(Icons.dashboard_customize), title: Text('Templates'), dense: true)),
      PopupMenuItem(value: 'my_templates', child: ListTile(leading: Icon(Icons.collections_bookmark), title: Text('My Templates'), dense: true)),
      PopupMenuDivider(),
      PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('Settings'), dense: true)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _designerBackground,
        colorScheme: ColorScheme.fromSeed(seedColor: _designerPurple, brightness: Brightness.light),
        appBarTheme: const AppBarTheme(backgroundColor: _designerSurface, foregroundColor: _designerText, elevation: 0),
        dividerColor: _designerBorder,
      ),
      child: Scaffold(
      backgroundColor: _designerBackground,
      appBar: AppBar(
        backgroundColor: _designerSurface,
        foregroundColor: _designerText,
        title: const Text('ARK Designer', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          _designerMenu(),
          IconButton(
            tooltip: 'Designer settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openDesignerSettings,
          ),
        ],
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
        Expanded(
          child: currentComponents.isEmpty
              ? const Center(child: Text('No components on this page. Tap Add component.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                  itemCount: currentComponents.length,
                  itemBuilder: (context, index) {
                    final component = currentComponents[index];
                    return _componentVisual(component, onEdit: () => _editComponent(component));
                  },
                ),
        ),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: saving || publishing ? null : _showComponentPicker,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add component'),
            ),
          ),
        )),
      ]),
      ),
    );
  }
}

class _DesignerSettingsPage extends StatefulWidget {
  const _DesignerSettingsPage({
    required this.saving,
    required this.publishing,
    required this.onSaveDraft,
    required this.onPublish,
  });
  final bool saving;
  final bool publishing;
  final Future<void> Function() onSaveDraft;
  final Future<void> Function() onPublish;

  @override
  State<_DesignerSettingsPage> createState() => _DesignerSettingsPageState();
}

class _DesignerSettingsPageState extends State<_DesignerSettingsPage> {
  bool busy = false;
  bool publishingAction = false;

  Future<void> _run(Future<void> Function() action, {required bool publish}) async {
    if (busy) return;
    setState(() { busy = true; publishingAction = publish; });
    try {
      await action();
    } finally {
      if (mounted) setState(() { busy = false; publishingAction = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final working = busy || widget.saving || widget.publishing;
    return Scaffold(
      appBar: AppBar(title: const Text('Designer Settings')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Publish & Sync', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('Save your current design as a draft or publish the configuration to the connected WordPress store.'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: working ? null : () => _run(widget.onSaveDraft, publish: false),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Draft'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: working ? null : () => _run(widget.onPublish, publish: true),
                        icon: const Icon(Icons.publish_rounded),
                        label: const Text('Publish JSON'),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.phone_android_rounded),
                  title: const Text('App Settings', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const _DesignerAppSettingsPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (working)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 42, height: 42, child: CircularProgressIndicator(strokeWidth: 4)),
                          const SizedBox(height: 14),
                          Text(publishingAction || widget.publishing ? 'Publishing…' : 'Saving draft…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesignerAppSettingsPage extends StatelessWidget {
  const _DesignerAppSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF24212B),
          elevation: 0,
        ),
      ),
      child: Scaffold(
        key: const ValueKey('designer-app-settings-page'),
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF24212B),
          title: const Text('App Settings'),
        ),
        body: const ColoredBox(
          color: Colors.white,
          child: SizedBox.expand(),
        ),
      ),
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
  bool _addingChild = false;
  bool _savingNow = false;
  DesignerComponent get item => widget.component;

  Future<void> _saveOnce() async {
    if (_savingNow) return;
    _savingNow = true;
    try {
      await widget.onSave();
    } finally {
      _savingNow = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _title.text = item.title;
    _description.text = (item.properties['description'] ?? '').toString();
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }

  void _change(String key, dynamic value) {
    setState(() {
      item.properties[key] = value;
      // Keep the native Designer model and the published Shopping renderer in sync.
      const aliases = <String, String>{
        'background_color': 'section_background',
        'title_color': 'text_color',
        'height': 'height_px',
        'max_cross_axis_extent': 'max_width_px',
        'border_radius': 'corner_radius',
        'cross_axis_count': 'columns',
        'cross_aspect_ratio': 'card_aspect_ratio',
        'elevation': 'card_depth',
        'fixed_grid_view_count': 'limit',
        'arrows': 'show_arrows',
        'dots': 'show_dots',
        'pause': 'pause_on_interaction',
      };
      final alias = aliases[key];
      if (alias != null) item.properties[alias] = value;
      if (key == 'width') item.properties['width_pct'] = ((value as num).toDouble() * 100);
      if (key == 'autoplay_seconds') item.properties['interval_ms'] = ((value as num).toDouble() * 1000).round();
      if (key == 'fade') item.properties['transition'] = value == true ? 'fade' : 'slide';
      if (key == 'view_fraction') item.properties['card_width'] = value;
      if (key == 'enabled') item.enabled = value == true;
      if (key == 'main_axis_spacing' || key == 'cross_axis_spacing') {
        item.properties['item_gap'] = value;
      }
      if (key == 'parent_category_id') item.properties['category_id'] = value;
      if (key == 'source_id' && item.properties['source'] == 'category') {
        item.properties['category_id'] = value;
      }
      if (key == 'source_id' && item.properties['source'] == 'tag') {
        item.properties['tag_id'] = value;
      }
      if (key == 'show_all_categories') {
        item.properties['limit'] = value == true ? 100 : 8;
        item.properties['fixed_grid_view_count'] = item.properties['limit'];
      }
    });
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

  Widget _slider(String label, String key, {double min = 0, double max = 300}) {
    final raw = (item.properties[key] as num?)?.toDouble() ?? min;
    final value = raw.clamp(min, max).toDouble();
    final decimals = (min < 0 || max <= 2.5) ? 2 : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text(value.toStringAsFixed(decimals),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        Slider(
          value: value,
          min: min,
          max: max,
          // Pixel dimensions, spacing and elevation are integer-valued in the
          // WordPress schema. Prevent fractional values that PHP sanitizes
          // (for example card_depth 13.30 -> 13) before Publish verification.
          divisions: decimals == 0 ? (max - min).round().clamp(1, 1000) : null,
          activeColor: _designerPurple,
          onChanged: (next) => _change(key, decimals == 0 ? next.roundToDouble() : next),
        ),
      ]),
    );
  }

  Widget _switch(String label, String key) => SwitchListTile(
    contentPadding: EdgeInsets.zero, title: Text(label), activeColor: _designerPurple,
    value: key == 'enabled' ? item.enabled : item.properties[key] == true,
    onChanged: (value) {
      if (key == 'enabled') {
        setState(() {
          item.enabled = value;
          item.properties['visible'] = value;
        });
        widget.onChanged();
      } else {
        _change(key, value);
      }
    },
  );

  Widget _childrenPanel() {
    final children = (item.properties['children'] is List
            ? List<dynamic>.from(item.properties['children'] as List)
            : <dynamic>[])
        .where((value) {
          if (value is! Map) return false;
          final type = (value['type'] ?? 'image').toString().toLowerCase();
          return type == 'image' || type == 'video';
        })
        .toList();

    return _section('Children', [
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const ValueKey('designer-add-child-image'),
          onPressed: _addingChild ? null : () async {
            setState(() => _addingChild = true);
            try {
              final media = await widget.onChooseMedia();
              if (!mounted || media == null) return;
              final source = (media['source_url'] ?? '').toString().trim();
              if (source.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('The selected media has no usable image URL.')),
                );
                return;
              }
              final updated = List<dynamic>.from(item.properties['children'] is List
                  ? item.properties['children'] as List
                  : const <dynamic>[]);
              final mime = (media['mime_type'] ?? 'image/jpeg').toString();
              updated.removeWhere((value) => value is! Map ||
                  !['image', 'video'].contains((value['type'] ?? 'image').toString().toLowerCase()));
              updated.add(<String, dynamic>{
                'type': mime.startsWith('video/') ? 'video' : 'image',
                'attachment_id': media['id'],
                'image_url': mime.startsWith('video/') ? '' : source,
                'video_url': mime.startsWith('video/') ? source : '',
                'source_url': source,
                'mime_type': mime,
                'title': '',
                'alt_text': (media['alt_text'] ?? '').toString(),
                'active': true,
              });
              _change('children', updated);
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open WordPress Media Library: ' + _friendlyDesignerError(error))),
                );
              }
            } finally {
              if (mounted) setState(() => _addingChild = false);
            }
          },
          icon: _addingChild
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_addingChild ? 'Opening Media Library…' : 'Add image from Media Library'),
        ),
      ),
      const SizedBox(height: 12),
      if (children.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: _designerField,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _designerBorder),
          ),
          child: const Column(children: [
            Icon(Icons.photo_library_outlined, size: 34, color: _designerMuted),
            SizedBox(height: 8),
            Text('No images added yet', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Add images from your WordPress Media Library.', textAlign: TextAlign.center,
                style: TextStyle(color: _designerMuted, fontSize: 12)),
          ]),
        )
      else
        ...children.asMap().entries.map((entry) {
          final child = Map<String, dynamic>.from(entry.value as Map);
          final type = (child['type'] ?? 'image').toString().toLowerCase();
          final src = (child['image_url'] ?? child['video_url'] ?? child['source_url'] ?? '').toString();
          final customTitle = (child['title'] ?? '').toString().trim();
          return Card(
            key: ValueKey('designer-child-${item.id}-${entry.key}'),
            color: _designerField,
            elevation: 0,
            child: ListTile(
              onTap: () => _editChild(entry.key),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 58, height: 58,
                  child: src.isEmpty
                      ? const ColoredBox(color: _designerBorder, child: Icon(Icons.image_outlined))
                      : Image.network(src, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: _designerBorder,
                              child: Icon(Icons.broken_image_outlined))),
                ),
              ),
              title: Text(customTitle.isEmpty ? 'Image ${entry.key + 1}' : customTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(type == 'video' ? 'VIDEO' : 'IMAGE'),
              trailing: IconButton(
                tooltip: 'Delete image',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  final updated = List<dynamic>.from(item.properties['children'] as List? ?? const <dynamic>[]);
                  final matching = updated.where((value) => value is Map &&
                      ['image', 'video'].contains((value['type'] ?? 'image').toString().toLowerCase())).toList();
                  if (entry.key < matching.length) {
                    final target = matching[entry.key];
                    updated.remove(target);
                    _change('children', updated);
                  }
                },
              ),
            ),
          );
        }),
      if (children.length > 1) ...[
        const SizedBox(height: 10),
        const Text('Reorder images', style: TextStyle(fontWeight: FontWeight.w800)),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            final updated = children.map((value) => Map<String, dynamic>.from(value as Map)).toList();
            if (newIndex > oldIndex) newIndex--;
            final moved = updated.removeAt(oldIndex);
            updated.insert(newIndex, moved);
            _change('children', updated);
          },
          children: children.asMap().entries.map((entry) => ListTile(
            key: ValueKey('child-order-${item.id}-${entry.key}'),
            leading: const Icon(Icons.drag_handle),
            title: Text((entry.value is Map && (entry.value as Map)['title']?.toString().trim().isNotEmpty == true)
                ? (entry.value as Map)['title'].toString()
                : 'Image ${entry.key + 1}'),
          )).toList(),
        ),
      ],
    ]);
  }

  Widget _titlePanel() => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      _section('Title', [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
          onChanged: (value) { item.title = value; widget.onChanged(); setState(() {}); },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Description'),
          onChanged: (value) => _change('description', value),
        ),
        _switch('Show Title', 'show_title'),
        _switch('Countdown Time', 'countdown_enabled'),
        if (item.properties['countdown_enabled'] == true)
          TextFormField(
            initialValue: (item.properties['countdown_time'] ?? '').toString(),
            decoration: const InputDecoration(labelText: 'Countdown date and time'),
            onChanged: (value) => _change('countdown_time', value),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openTextStyle,
          icon: const Icon(Icons.text_format_rounded),
          label: const Text('Title Text Style'),
        ),
      ]),
    ],
  );

  Widget _openColorPanel() => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      _section('Color', [
        _colorChoice('Background Color', 'background_color', const ['#FFFFFF', '#F7F7FA', '#F1ECFF', '#E8F6F0', '#FFF0E6', '#202033']),
        _colorChoice('Title Color', 'title_color', const ['#24212B', '#51408F', '#FFFFFF', '#B23B32', '#16734A']),
        _colorChoice('Text Color', 'text_color', const ['#24212B', '#FFFFFF', '#7650B8', '#B23B32', '#16734A']),
      ]),
    ],
  );

  Widget _backgroundImageSettings() {
    final imageUrl = (item.properties['background_image_url'] ?? '').toString();
    final alignment = (item.properties['background_image_alignment'] ?? 'center').toString();
    final fit = (item.properties['background_image_fit'] ?? 'cover').toString();
    final screenWidth = MediaQuery.of(context).size.width;
    final marginWidth = ((item.properties['margin_left'] as num?)?.toDouble() ?? 0) + ((item.properties['margin_right'] as num?)?.toDouble() ?? 0);
    final paddingWidth = ((item.properties['padding_left'] as num?)?.toDouble() ?? 12) + ((item.properties['padding_right'] as num?)?.toDouble() ?? 12);
    final availableWidth = (screenWidth - marginWidth - paddingWidth).clamp(80, screenWidth);
    final widthFactor = ((item.properties['width'] as num?)?.toDouble() ?? 1).clamp(.2, 1.0);
    final maxExtent = (item.properties['max_cross_axis_extent'] as num?)?.toDouble();
    final cardWidth = (availableWidth * widthFactor).clamp(80, maxExtent ?? availableWidth).toDouble();
    final cardHeight = ((item.properties['height'] ?? item.properties['height_px']) as num?)?.toDouble() ?? 180;
    final recommendedWidth = (cardWidth * 2).round();
    final recommendedHeight = (cardHeight * 2).round();
    return _section('Background Image / GIF', [
      const Text(
        'Set an image or animated GIF behind this component. Child cards remain in front.',
        style: TextStyle(color: _designerMuted, fontSize: 12),
      ),
      const SizedBox(height: 8),
      if (imageUrl.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(imageUrl, height: 110, width: double.infinity,
            fit: _designerBackgroundFit(fit),
            alignment: _designerBackgroundAlignment(alignment),
            errorBuilder: (_, __, ___) => const SizedBox(height: 80,
              child: Center(child: Icon(Icons.broken_image_outlined)))),
        ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          icon: const Icon(Icons.wallpaper_outlined),
          label: Text(imageUrl.isEmpty ? 'Choose Background' : 'Change Background'),
          onPressed: _addingChild ? null : () async {
            setState(() => _addingChild = true);
            try {
              final media = await widget.onChooseMedia();
              if (!mounted || media == null) return;
              _change('background_image_url', media['source_url'] ?? '');
              _change('background_image_mime_type', media['mime_type'] ?? 'image/jpeg');
            } finally {
              if (mounted) setState(() => _addingChild = false);
            }
          },
        )),
        if (imageUrl.isNotEmpty) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove background image',
            onPressed: () {
              _change('background_image_url', '');
              _change('background_image_mime_type', '');
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ]),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: const ['top_left','top_center','top_right','center_left','center','center_right','bottom_left','bottom_center','bottom_right'].contains(alignment) ? alignment : 'center',
        decoration: const InputDecoration(labelText: 'Background Image Position'),
        items: const [
          DropdownMenuItem(value: 'top_left', child: Text('Top left')),
          DropdownMenuItem(value: 'top_center', child: Text('Top center')),
          DropdownMenuItem(value: 'top_right', child: Text('Top right')),
          DropdownMenuItem(value: 'center_left', child: Text('Center left')),
          DropdownMenuItem(value: 'center', child: Text('Center')),
          DropdownMenuItem(value: 'center_right', child: Text('Center right')),
          DropdownMenuItem(value: 'bottom_left', child: Text('Bottom left')),
          DropdownMenuItem(value: 'bottom_center', child: Text('Bottom center')),
          DropdownMenuItem(value: 'bottom_right', child: Text('Bottom right')),
        ],
        onChanged: (value) { if (value != null) _change('background_image_alignment', value); },
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: const ['cover','contain','fill','fit_width','fit_height'].contains(fit) ? fit : 'cover',
        decoration: const InputDecoration(labelText: 'Background Image Fit'),
        items: const [
          DropdownMenuItem(value: 'cover', child: Text('Cover (fill area)')),
          DropdownMenuItem(value: 'contain', child: Text('Contain (show full image)')),
          DropdownMenuItem(value: 'fill', child: Text('Stretch to fit')),
          DropdownMenuItem(value: 'fit_width', child: Text('Fit width')),
          DropdownMenuItem(value: 'fit_height', child: Text('Fit height')),
        ],
        onChanged: (value) { if (value != null) _change('background_image_fit', value); },
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _designerField, borderRadius: BorderRadius.circular(10), border: Border.all(color: _designerBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Auto image size suggestion', style: TextStyle(fontWeight: FontWeight.w700, color: _designerPurple)),
          const SizedBox(height: 4),
          Text('Estimated card size: ' + cardWidth.round().toString() + ' × ' + cardHeight.round().toString() + ' logical px.'),
          Text('Recommended upload: ' + recommendedWidth.toString() + ' × ' + recommendedHeight.toString() + ' px (2× resolution).'),
          const Text('Keep the same aspect ratio to reduce cropping.', style: TextStyle(color: _designerMuted, fontSize: 11)),
        ]),
      ),
    ]);
  }

  Widget _settingsPanel(List<String> layouts) => ListView(
    padding: const EdgeInsets.all(14),
    children: [
      _section('Settings', [
        _switch('Component Status', 'enabled'),
        DropdownButtonFormField<String>(
          initialValue: layouts.contains(item.layout) ? item.layout : layouts.first,
          decoration: const InputDecoration(labelText: 'Layout'),
          items: layouts.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              item.layout = value;
              final prefix = item.type.toLowerCase();
              final suffix = value.toLowerCase().replaceFirst('${prefix} ', '').replaceAll(' ', '_');
              item.properties['designer_component_type'] = '${prefix}_${suffix}';
              item.properties['layout_variant'] = suffix;
              if (item.type == 'Banner') item.properties['type'] = item.properties['designer_component_type'];
              if (item.type == 'Category') item.properties['category_layout'] = suffix;
            });
            widget.onChanged();
          },
        ),
        if (item.type == 'Category') ...[
          _switch('Show All Categories', 'show_all_categories'),
          TextFormField(
            initialValue: (item.properties['parent_category_id'] ?? 0).toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Parent Category ID (0 = all)'),
            onChanged: (value) => _change('parent_category_id', int.tryParse(value) ?? 0),
          ),
        ],
        if (item.type == 'Product') ...[
          DropdownButtonFormField<String>(
            initialValue: (item.properties['source'] ?? 'featured').toString(),
            decoration: const InputDecoration(labelText: 'Product source'),
            items: const [
              DropdownMenuItem(value: 'latest', child: Text('Latest / New Arrival')),
              DropdownMenuItem(value: 'featured', child: Text('Featured')),
              DropdownMenuItem(value: 'category', child: Text('Category')),
              DropdownMenuItem(value: 'tag', child: Text('Product Tag')),
              DropdownMenuItem(value: 'on_sale', child: Text('On Sale')),
              DropdownMenuItem(value: 'wishlist', child: Text('Wishlist')),
              DropdownMenuItem(value: 'best_selling', child: Text('Best Selling')),
              DropdownMenuItem(value: 'top_rated', child: Text('Top Rated')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                item.properties['source'] = value;
                item.properties['source_id'] = 0;
                if (value == 'category') {
                  item.properties['category_id'] = 0;
                } else if (value == 'tag') {
                  item.properties['tag_id'] = 0;
                }
              });
              widget.onChanged();
            },
          ),
          if (['category','tag'].contains(item.properties['source']))
            TextFormField(
              initialValue: (item.properties['source_id'] ?? 0).toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '${item.properties['source'] == 'tag' ? 'Tag' : 'Category'} ID'),
              onChanged: (value) => _change('source_id', int.tryParse(value) ?? 0),
            ),
        ],
      ]),
      _childrenPanel(),
      if (item.layout.toLowerCase().contains('grid') ||
          item.layout.toLowerCase().contains('slider') ||
          item.layout.toLowerCase().contains('scroll'))
        _backgroundImageSettings(),
    ],
  );

  Widget _stylePanel() {
    if (item.type != 'Banner') {
      return ListView(padding: const EdgeInsets.all(14), children: [
        _section('Style', [
          _switch('Italic', 'italic'),
          _slider('Font Size', 'title_font_size', min: 8, max: 72),
          _slider('Letter Spacing', 'letter_spacing', min: 0, max: 20),
          _slider('Word Spacing', 'word_spacing', min: 0, max: 30),
          OutlinedButton.icon(onPressed: _openTextStyle, icon: const Icon(Icons.font_download_outlined), label: Text('Font Family: ${item.properties['font_family'] ?? 'Roboto'}')),
        ]),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(14), children: [
      _section('Banner Style', [
        _switch('Control', 'control'),
        _switch('Autoplay', 'autoplay'),
        if (item.properties['autoplay'] == true) _slider('Autoplay interval (seconds)', 'autoplay_seconds', min: 2, max: 15),
        _slider('View Fraction', 'view_fraction', min: .4, max: 1),
        _switch('Fade', 'fade'),
        _switch('Pause on touch', 'pause'),
        _switch('Dot', 'dots'),
        _switch('Arrow', 'arrows'),
      ]),
    ]);
  }

  Future<void> _showComponentJson() async {
    final json = const JsonEncoder.withIndent('  ').convert(item.toPublishedSection());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _designerSurface,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .8,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                const Expanded(child: Text('Live Component JSON', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: 'Copy JSON',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    // Clipboard is supplied by Flutter services without a plugin.
                    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(item.toPublishedSection())));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Component JSON copied')));
                  },
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: SelectableText(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openTextStyle() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _DesignerTextStylePage(
        properties: Map<String, dynamic>.from(item.properties),
      )),
    );
    if (result != null) {
      setState(() => item.properties.addAll(result));
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final layouts = _GlowHitDesignerPageState._layoutTypes[item.type]!;
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: _designerPurple, brightness: Brightness.light, surface: _designerSurface),
        scaffoldBackgroundColor: _designerBackground,
        appBarTheme: const AppBarTheme(backgroundColor: _designerSurface, foregroundColor: _designerText),
        cardTheme: const CardThemeData(color: _designerSurface, surfaceTintColor: Colors.transparent),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _designerField,
          labelStyle: const TextStyle(color: _designerMuted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _designerBorder)),
        ),
      ),
      child: DefaultTabController(
        length: 7,
        child: Scaffold(
          backgroundColor: _designerBackground,
          appBar: AppBar(
            title: Text('${item.type} Layout'),
            actions: [
              IconButton(
                tooltip: 'View live component JSON',
                icon: const Icon(Icons.data_object_rounded),
                onPressed: _showComponentJson,
              ),
              IconButton(
                tooltip: 'Delete component',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async { await widget.onDelete(); if (context.mounted) Navigator.pop(context); },
              ),
              TextButton(
                onPressed: _savingNow ? null : () async { await _saveOnce(); if (context.mounted) Navigator.pop(context); },
                child: const Text('Done'),
              ),
            ],
          ),
          body: Column(children: [
            // Full-width editing canvas: render with the same viewport width as
            // Shopping Home. Avoid FittedBox(scaleDown), which shrank components
            // to their intrinsic width and left the preview surrounded by blank bars.
            Expanded(
              flex: 5,
              child: ColoredBox(
                color: _designerBackground,
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    width: constraints.maxWidth,
                    child: ClipRect(child: widget.visualBuilder()),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _designerPurple,
              unselectedLabelColor: _designerMuted,
              indicatorColor: _designerPurple,
              tabs: [
                Tab(text: 'Color'),
                Tab(text: 'Title'),
                Tab(text: 'Padding'),
                Tab(text: 'Margin'),
                Tab(text: 'Dimension'),
                Tab(text: 'Settings'),
                Tab(text: 'Style'),
              ],
            ),
            Expanded(
              flex: 6,
              child: TabBarView(children: [
                _openColorPanel(),
                _titlePanel(),
                ListView(padding: const EdgeInsets.all(14), children: [
                  _section('Padding', [
                    _slider('Top', 'padding_top'), _slider('Bottom', 'padding_bottom'),
                    _slider('Right', 'padding_right'), _slider('Left', 'padding_left'),
                  ]),
                ]),
                ListView(padding: const EdgeInsets.all(14), children: [
                  _section('Margin', [
                    _slider('Top', 'margin_top'), _slider('Bottom', 'margin_bottom'),
                    _slider('Right', 'margin_right'), _slider('Left', 'margin_left'),
                  ]),
                ]),
                ListView(padding: const EdgeInsets.all(14), children: [
                  _section('Dimension', [
                    _slider('Height', 'height', min: 40, max: 500),
                    _slider('Width', 'width', min: .25, max: 1),
                    _slider('Max Cross Axis Extent', 'max_cross_axis_extent', min: 80, max: 600),
                    _slider('Main Axis Spacing', 'main_axis_spacing', max: 60),
                    _slider('Cross Axis Spacing', 'cross_axis_spacing', max: 60),
                    _slider('Border Radius', 'border_radius', max: 60),
                    _switch('Horizontal', 'horizontal'),
                    _slider('Cross Axis Count', 'cross_axis_count', min: 1, max: 6),
                    _slider('Cross Aspect Ratio', 'cross_aspect_ratio', min: .4, max: 2.5),
                    _slider('Elevation', 'elevation', max: 20),
                    _slider('Fixed Grid View Count', 'fixed_grid_view_count', min: 1, max: 40),
                  ]),
                ]),
                _settingsPanel(layouts),
                _stylePanel(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _editChild(int index) async {
    final rows = item.properties['children'] is List ? List<dynamic>.from(item.properties['children'] as List) : <dynamic>[];
    if (index < 0 || index >= rows.length || rows[index] is! Map) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _DesignerChildEditPage(
        child: Map<String, dynamic>.from(rows[index] as Map),
        onChooseMedia: widget.onChooseMedia,
      )),
    );
    if (result == null) return;
    if (result['_delete'] == true) {
      rows.removeAt(index);
    } else {
      rows[index] = result;
    }
    _change('children', rows);
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

class _DesignerTextStylePage extends StatefulWidget {
  const _DesignerTextStylePage({required this.properties});
  final Map<String, dynamic> properties;

  @override
  State<_DesignerTextStylePage> createState() => _DesignerTextStylePageState();
}

class _DesignerTextStylePageState extends State<_DesignerTextStylePage> {
  late Map<String, dynamic> values;

  static const _textColors = <String>['#24212B', '#FFFFFF', '#7650B8', '#B23B32', '#16734A', '#1B6CA8'];
  static const _backgroundColors = <String>['#FFFFFF', '#F1EFF5', '#202033', '#FFF0E6', '#E8F6F0', '#00000000'];

  @override
  void initState() {
    super.initState();
    values = Map<String, dynamic>.from(widget.properties);
  }

  Color _color(String hex) {
    final raw = hex.replaceFirst('#', '');
    final parsed = int.tryParse(raw, radix: 16) ?? 0xFF24212B;
    if (raw.length == 8) return Color(parsed);
    return Color(0xFF000000 | parsed);
  }

  void _set(String key, dynamic value) => setState(() => values[key] = value);

  Widget _swatches(String title, String key, List<String> colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: colors.map((hex) => InkWell(
          onTap: () => _set(key, hex),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _color(hex),
              shape: BoxShape.circle,
              border: Border.all(color: values[key] == hex ? _designerPurple : _designerBorder, width: values[key] == hex ? 3 : 1),
            ),
          ),
        )).toList()),
      ]),
    );
  }

  Widget _slider(String label, String key, {double min = 0, double max = 60, double fallback = 0}) {
    final value = ((values[key] as num?)?.toDouble() ?? fallback).clamp(min, max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(children: [
        Row(children: [Expanded(child: Text(label)), Text(value.toStringAsFixed(1))]),
        Slider(
          value: value, min: min, max: max, activeColor: _designerPurple,
          onChanged: (next) => _set(key, next),
        ),
      ]),
    );
  }

  Future<void> _searchFont() async {
    const fonts = <String>[
      'Roboto', 'ABeeZee', 'Abel', 'Abhaya Libre', 'Aboreto', 'Abril Fatface',
      'Abyssinica SIL', 'Afacad', 'Alegreya', 'Anton', 'Archivo', 'Barlow',
      'Bebas Neue', 'Bitter', 'Cabin', 'Cairo', 'Comfortaa', 'DM Sans',
      'Dancing Script', 'Exo 2', 'Fira Sans', 'Georgia', 'Inter', 'Lato',
      'Merriweather', 'Montserrat', 'Nunito', 'Open Sans', 'Oswald',
      'Playfair Display', 'Poppins', 'Raleway', 'Roboto Condensed', 'Ubuntu'
    ];
    final controller = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _designerSurface,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
        final query = controller.text.toLowerCase();
        final filtered = fonts.where((font) => font.toLowerCase().contains(query)).toList();
        return SafeArea(child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .84,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: controller,
                onChanged: (_) => refresh(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search Font'),
              ),
            ),
            Expanded(child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, index) => ListTile(
                title: Text('Almost before we knew it', style: TextStyle(fontFamily: filtered[index], fontSize: 19)),
                subtitle: Text(filtered[index]),
                onTap: () => Navigator.pop(ctx, filtered[index]),
              ),
            )),
          ]),
        ));
      }),
    );
    controller.dispose();
    if (selected != null) _set('font_family', selected);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _color((values['title_color'] ?? '#24212B').toString());
    final background = _color((values['title_background_color'] ?? '#00000000').toString());
    final fontSize = (values['title_font_size'] as num?)?.toDouble() ?? 24;
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _designerBackground,
        colorScheme: ColorScheme.fromSeed(seedColor: _designerPurple),
        appBarTheme: const AppBarTheme(backgroundColor: _designerSurface, foregroundColor: _designerText),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Text Style'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, values), child: const Text('DONE')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 170),
              alignment: Alignment.center,
              color: background,
              child: Text(
                'Sample Text',
                textAlign: TextAlign.center,
                style: _designerFontStyle(
                  (values['font_family'] ?? 'Roboto').toString(),
                  TextStyle(
                  color: textColor,
                  backgroundColor: background,
                  fontSize: fontSize,
                  fontWeight: (values['title_font_weight'] ?? 'normal') == 'bold' ? FontWeight.bold
                      : (values['title_font_weight'] ?? 'normal') == 'medium' ? FontWeight.w500 : FontWeight.normal,
                  fontStyle: values['italic'] == true ? FontStyle.italic : FontStyle.normal,
                  fontFamily: (values['font_family'] ?? 'Roboto').toString(),
                  letterSpacing: (values['letter_spacing'] as num?)?.toDouble() ?? 0,
                  wordSpacing: (values['word_spacing'] as num?)?.toDouble() ?? 0,
                )),
              ),
            ),
            const SizedBox(height: 20),
            _swatches('Color', 'title_color', _textColors),
            _swatches('Background Color', 'title_background_color', _backgroundColors),
            DropdownButtonFormField<String>(
              initialValue: (values['title_font_weight'] ?? 'normal').toString(),
              decoration: const InputDecoration(labelText: 'Font weight'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'bold', child: Text('Bold')),
              ],
              onChanged: (value) { if (value != null) _set('title_font_weight', value); },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Italic'),
              value: values['italic'] == true,
              onChanged: (value) => _set('italic', value),
            ),
            _slider('Font Size', 'title_font_size', min: 8, max: 72, fallback: 24),
            _slider('Letter Spacing', 'letter_spacing', max: 20),
            _slider('Word Spacing', 'word_spacing', max: 30),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Font Family'),
              subtitle: Text((values['font_family'] ?? 'Roboto').toString()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _searchFont,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignerChildEditPage extends StatefulWidget {
  const _DesignerChildEditPage({required this.child, required this.onChooseMedia});
  final Map<String, dynamic> child;
  final Future<Map<String, dynamic>?> Function() onChooseMedia;

  @override
  State<_DesignerChildEditPage> createState() => _DesignerChildEditPageState();
}

class _DesignerChildEditPageState extends State<_DesignerChildEditPage> {
  late Map<String, dynamic> child;
  late final TextEditingController title;
  bool selectingImage = false;

  @override
  void initState() {
    super.initState();
    child = Map<String, dynamic>.from(widget.child);
    title = TextEditingController(text: (child['title'] ?? '').toString());
  }

  @override
  void dispose() { title.dispose(); super.dispose(); }

  Future<void> _selectImage() async {
    if (selectingImage) return;
    setState(() => selectingImage = true);
    try {
      final media = await widget.onChooseMedia();
      if (!mounted || media == null) return;
      final url = (media['source_url'] ?? '').toString().trim();
      if (url.isEmpty) return;
      setState(() {
        child['type'] = 'image';
        child['attachment_id'] = media['id'];
        child['image_url'] = url;
        child['video_url'] = '';
        child['source_url'] = url;
        child['mime_type'] = media['mime_type'] ?? 'image/jpeg';
        child['alt_text'] = media['alt_text'] ?? '';
        // Media Library titles are metadata only. The user may enter a title
        // manually, but selecting/replacing an image always clears it.
        child['title'] = '';
        title.clear();
      });
    } finally {
      if (mounted) setState(() => selectingImage = false);
    }
  }

  Future<void> _chooseLink() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const ListTile(title: Text('Choose child destination', style: TextStyle(fontWeight: FontWeight.w800))),
          for (final entry in const <MapEntry<String, String>>[
            MapEntry('page:home', 'Home'),
            MapEntry('page:categories', 'Categories'),
            MapEntry('page:wishlist', 'Wishlist'),
            MapEntry('page:cart', 'Cart'),
            MapEntry('page:account', 'Account'),
            MapEntry('page:orders', 'My Orders'),
          ])
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: Text(entry.value),
              onTap: () => Navigator.pop(ctx, entry.key),
            ),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Product by ID'),
            onTap: () => Navigator.pop(ctx, '__product_id__'),
          ),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: const Text('Remove link'),
            onTap: () => Navigator.pop(ctx, '__clear__'),
          ),
        ]),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == '__clear__') {
      setState(() {
        child.remove('link_type');
        child.remove('link_value');
      });
      return;
    }
    if (selected == '__product_id__') {
      final controller = TextEditingController();
      final id = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Product ID'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'WooCommerce product ID'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      controller.dispose();
      final productId = int.tryParse(id ?? '');
      if (productId == null || productId < 1) return;
      setState(() {
        child['link_type'] = 'in_app';
        child['link_value'] = 'product:$productId';
      });
      return;
    }
    setState(() {
      child['link_type'] = 'in_app';
      child['link_value'] = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (child['image_url'] ?? child['source_url'] ?? '').toString();
    return Scaffold(
      backgroundColor: _designerBackground,
      appBar: AppBar(
        title: const Text('Child'),
        backgroundColor: _designerSurface,
        foregroundColor: _designerText,
        actions: [
          IconButton(
            tooltip: 'Delete child',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.pop(context, <String, dynamic>{'_delete': true}),
          ),
          TextButton(onPressed: () {
            child['title'] = title.text.trim();
            Navigator.pop(context, child);
          }, child: const Text('SAVE')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: _designerSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _designerBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imageUrl.isEmpty
                      ? const ColoredBox(color: _designerField,
                          child: Center(child: Icon(Icons.image_outlined, size: 42, color: _designerMuted)))
                      : Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: _designerField,
                              child: Center(child: Icon(Icons.broken_image_outlined, size: 42)))),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: selectingImage ? null : _selectImage,
                icon: selectingImage
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.photo_library_outlined),
                label: Text(selectingImage ? 'Opening Media Library…' : 'Choose image'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  hintText: 'Leave blank to show no title',
                ),
                onChanged: (value) => child['title'] = value,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseLink,
                icon: const Icon(Icons.link_rounded),
                label: Text(
                  (child['link_value'] ?? '').toString().isEmpty
                      ? 'Add link destination'
                      : 'Link: ${child['link_value']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          tileColor: _designerSurface,
          title: const Text('Status'),
          value: child['active'] != false,
          onChanged: (value) => setState(() => child['active'] = value),
        ),
      ]),
    );
  }
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
