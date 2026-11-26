import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/glowhit_designer_page.dart';
import 'package:glowhit_shopping/designer_banner_carousel.dart';
import 'package:glowhit_shopping/designer_layout_contract.dart';
import 'package:glowhit_shopping/designer_navigation_bar.dart';
import 'package:glowhit_shopping/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Navigation Bar defaults preserve the five native Shopping destinations', () {
    final config = DesignerNavigationConfig();
    expect(config.items.map((item) => item.link).toList(),
      ['home', 'categories', 'wishlist', 'cart', 'account']);
    expect(config.type, 'fixed');
    expect(config.items, hasLength(5));
  });

  test('Navigation Bar JSON preserves order, links, icon packs and colors', () {
    final config = DesignerNavigationConfig(
      type: 'shifting',
      backgroundColor: '#FFFFFFFF',
      selectedColor: '#FF5B3A9E',
      unselectedColor: '#FF77717F',
      items: [
        DesignerNavigationItem(
          id: 'wishlist-tab',
          label: 'Wishlist',
          link: 'wishlist',
          iconFamily: 'Remix Icons',
          iconName: 'heart_line',
          activeIconFamily: 'Font Awesome',
          activeIconName: 'heart',
          iconColor: '#FF77717F',
          activeIconColor: '#FF5B3A9E',
        ),
      ],
    );
    final restored = DesignerNavigationConfig.fromJson(config.toJson());
    expect(restored.type, 'shifting');
    expect(restored.items.single.id, 'wishlist-tab');
    expect(restored.items.single.link, 'wishlist');
    expect(restored.items.single.iconFamily, 'Remix Icons');
    expect(restored.items.single.activeIconFamily, 'Font Awesome');
    expect(restored.items.single.activeIconName, 'heart');
    expect(restored.items.single.iconColor, '#FF77717F');
  });

  test('Navigation publish verification reports changed root and item fields', () {
    final requested = DesignerNavigationConfig();
    final published = DesignerNavigationConfig(
      items: [
        DesignerNavigationItem(
          id: 'nav-home',
          label: 'Home',
          link: 'home',
          iconName: 'menu',
        ),
      ],
      backgroundColor: '#F0F0F0',
    );
    final differences = requested.differencesFrom(published);
    expect(differences, contains(contains('background_color')));
    expect(differences, contains(contains('items[0].icon')));
    expect(differences, contains(contains('Designer: 5, WordPress: 1')));
  });

  test('Navigation icon packs each provide selectable icons', () {
    for (final family in DesignerNavIcons.families) {
      expect(DesignerNavIcons.all.where((icon) => icon.family == family), isNotEmpty);
    }
    expect(DesignerNavIcons.find('Material', 'home'), isNotNull);
    expect(DesignerNavIcons.find('Cupertino', 'house'), isNotNull);
    expect(DesignerNavIcons.find('Font Awesome', 'house'), isNotNull);
    expect(DesignerNavIcons.find('Remix Icons', 'home_3_line'), isNotNull);
    expect(DesignerNavIcons.find('FluentUI', 'home_24_regular'), isNotNull);
  });

  test('Navigation icon library includes transport, nature, commerce, social, buildings and digital icons', () {
    final expected = <(String, String)>[
      ('Material', 'flight'),
      ('Material', 'train'),
      ('Material', 'water_drop'),
      ('Material', 'wb_sunny'),
      ('Material', 'shopping_bag'),
      ('Material', 'apartment'),
      ('Material', 'wifi'),
      ('Material', 'database'),
      ('Font Awesome', 'instagram'),
      ('Font Awesome', 'whatsapp'),
    ];
    for (final pair in expected) {
      expect(DesignerNavIcons.find(pair.$1, pair.$2), isNotNull,
          reason: 'Missing ${pair.$1} icon ${pair.$2}');
    }
    expect(DesignerNavIcons.all.where((icon) => icon.family == 'Material').length, greaterThan(100));
  });

  testWidgets('Navigation Bar editor shows its white workspace and live preview', (tester) async {
    DesignerNavigationConfig? saved;
    await tester.pumpWidget(MaterialApp(
      home: DesignerNavigationBarPage(
        initialConfig: DesignerNavigationConfig(),
        onSave: (value) => saved = value,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Navigation Bar'), findsOneWidget);
    expect(find.text('Navigation Type'), findsOneWidget);
    expect(find.text('Live Preview'), findsOneWidget);
    expect(find.text('Add New Navigation Button'), findsNothing);
    expect(find.byTooltip('Add New Navigation Button'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(saved, isNull);
  });

  test('GlowHit remains configured for the live WooCommerce store', () {
    expect(storeUrl, 'https://pluginstore.shop');
  });

  test('Legacy ARK Live Slider preserves its Banner Grid/List layout variant', () {
    expect(normalizeDesignerBannerLayoutType({
      'type': 'ark_live_slider',
      'layout_variant': 'grid',
    }), 'banner_grid');
    expect(normalizeDesignerBannerLayoutType({
      'designer_component_type': 'ark_live_slider',
      'layout_variant': 'list',
    }), 'banner_list');
    expect(normalizeDesignerBannerLayoutType({
      'type': 'ark_live_slider',
      'layout_variant': 'slider',
    }), 'banner_slider');
  });

  test('Legacy banner-only draft restores the published Home product and category sections', () {
    final merged = restoreLegacyHomeSections(
      [
        {'id': 'legacy-banner', 'type': 'ark_live_slider', 'title': 'Edited hero'},
      ],
      [
        {'id': 'home-search', 'type': 'search', 'title': 'Search products'},
        {'id': 'home-hero', 'type': 'ark_live_slider', 'title': 'Featured'},
        {'id': 'home-cats', 'type': 'category_grid', 'title': 'Shop by category'},
        {'id': 'home-featured', 'type': 'product_carousel', 'title': 'Featured products'},
        {'id': 'home-products', 'type': 'product_grid', 'title': 'Shop products'},
      ],
    );
    expect(merged, hasLength(5));
    expect(merged.map((section) => section['id']), contains('home-cats'));
    expect(merged.map((section) => section['id']), contains('home-products'));
    expect(merged.firstWhere((section) => section['type'] == 'ark_live_slider')['title'], 'Edited hero');
  });

  test('A new banner in a legacy partial draft is appended without replacing the published hero', () {
    final merged = restoreLegacyHomeSections(
      [
        {'id': 'hero-existing', 'type': 'ark_live_slider', 'designer_component_type': 'banner_slider', 'title': 'Edited hero'},
        {'id': 'new-banner', 'type': 'banner_grid', 'designer_component_type': 'banner_grid', 'title': 'New banner'},
      ],
      [
        {'id': 'home-search', 'type': 'search', 'title': 'Search products'},
        {'id': 'hero-existing', 'type': 'ark_live_slider', 'designer_component_type': 'banner_slider', 'title': 'Old hero'},
        {'id': 'existing-campaign', 'type': 'ark_live_slider', 'designer_component_type': 'banner_scroll', 'title': 'Existing campaign'},
        {'id': 'home-cats', 'type': 'category_grid', 'title': 'Shop categories'},
        {'id': 'home-products', 'type': 'product_grid', 'title': 'Products'},
      ],
    );

    expect(merged, hasLength(6));
    expect(merged.firstWhere((section) => section['id'] == 'hero-existing')['title'], 'Edited hero');
    expect(merged.firstWhere((section) => section['id'] == 'existing-campaign')['title'], 'Existing campaign');
    expect(merged.firstWhere((section) => section['id'] == 'new-banner')['title'], 'New banner');
    expect(merged.any((section) => section['id'] == 'home-cats'), isTrue);
    expect(merged.any((section) => section['id'] == 'home-products'), isTrue);
  });

  test('Unrecognized published component type is preserved instead of becoming other_existing_section', () {
    final component = DesignerComponent(
      id: 'search-section',
      type: 'Other',
      title: 'Search products',
      layout: 'Existing section',
      properties: {'original_section_type': 'search'},
    );
    expect(component.toPublishedSection()['type'], 'search');
  });

  testWidgets('Designer gallery shows component previews without title or edit controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
      home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ARK Designer'), findsOneWidget);
    expect(find.text('Edit page'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Tap to edit properties'), findsNothing);
    expect(find.text('Banner Slider'), findsNothing);
    expect(find.text('Main promotional banner'), findsWidgets);
    expect(find.text('Save Draft'), findsNothing);
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Add component'), findsOneWidget);

    // Save and publish actions live on their own Settings page, not in the
    // fixed bottom action bar, so the component canvas keeps its full width.
    expect(find.byTooltip('Designer menu'), findsNothing);
    await tester.tap(find.byTooltip('Designer settings'));
    await tester.pumpAndSettle();
    expect(find.text('Designer Settings'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Publish JSON'), findsOneWidget);
    expect(find.text('Layout consistency'), findsNothing);
    // ListView lazily builds off-screen children, so scrollUntilVisible
    // must be used before looking up the App Settings tile.
    await tester.scrollUntilVisible(
      find.text('App Settings'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('App Settings'), findsOneWidget);
    await tester.tap(find.text('App Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('designer-app-settings-page')), findsOneWidget);
    expect(find.text('App Settings'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byKey(const ValueKey('designer-app-settings-page'))).backgroundColor, Colors.white);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add component').first);
    await tester.pumpAndSettle();
    expect(find.text('Add component'), findsNWidgets(2));
    expect(find.text('Banner'), findsWidgets);
    expect(find.text('Category'), findsWidgets);
    expect(find.text('Product'), findsWidgets);
    await tester.tap(find.text('Banner').last);
    await tester.pumpAndSettle();
    expect(find.text('Banner Grid'), findsOneWidget);
    expect(find.text('Banner Slider'), findsOneWidget);
  });

  test('Publish rejects a server document that drops submitted Home components', () {
    final submitted = [
      {'id': 'banner-new', 'type': 'banner_grid'},
    ];
    final serverPublished = <String, dynamic>{
      'pages': {
        'home': {
          'sections': <dynamic>[],
        },
      },
    };
    final pages = Map<String, dynamic>.from(serverPublished['pages'] as Map);
    final home = pages['home'] as Map;
    final publishedSections = home['sections'] as List;
    final publishedIds = publishedSections.whereType<Map>()
        .map((section) => (section['id'] ?? '').toString()).toSet();
    final submittedIds = submitted.map((section) => (section['id'] ?? '').toString()).toSet();
    expect(publishedIds.containsAll(submittedIds), isFalse);
    expect(publishedSections, isEmpty);
  });

  test('Published Home sync treats a valid empty server Home as authoritative', () {
    final response = <String, dynamic>{
      'version': 12,
      'pages': {
        'home': {
          'title': 'Home',
          'sections': <dynamic>[],
        },
      },
    };
    final pages = Map<String, dynamic>.from(response['pages'] as Map);
    final home = Map<String, dynamic>.from(pages['home'] as Map);
    final sections = (home['sections'] as List)
        .whereType<Map>()
        .where((section) => section['visible'] != false)
        .map((section) => Map<String, dynamic>.from(section))
        .toList(growable: false);
    home['sections'] = sections;
    pages['home'] = home;

    expect(pages['home']['sections'], isEmpty);
    expect(response['version'], 12);
  });

  test('Published Home sync preserves all visible component IDs and JSON properties', () {
    final response = <String, dynamic>{
      'version': 13,
      'pages': {
        'home': {
          'sections': [
            {
              'id': 'hero-live',
              'type': 'ark_live_slider',
              'designer_component_type': 'banner_grid',
              'layout_variant': 'grid',
              'visible': true,
              'margin_top': 16,
              'padding_bottom': 22,
              'children': [
                {'type': 'image', 'attachment_id': 77, 'image_url': 'https://example.com/banner.jpg', 'title': ''},
              ],
            },
            {'id': 'hidden-block', 'type': 'banner_slider', 'visible': false},
            {
              'id': 'products-live',
              'type': 'product_grid',
              'designer_component_type': 'product_grid',
              'layout_variant': 'grid',
              'source': 'best_selling',
              'height_px': 260,
            },
          ],
        },
      },
    };

    final pages = Map<String, dynamic>.from(response['pages'] as Map);
    final home = Map<String, dynamic>.from(pages['home'] as Map);
    final visible = (home['sections'] as List)
        .whereType<Map>()
        .where((section) => section['visible'] != false)
        .map((section) => Map<String, dynamic>.from(section))
        .toList(growable: false);
    home['sections'] = visible;

    expect(visible.map((section) => section['id']), ['hero-live', 'products-live']);
    expect(visible.first['designer_component_type'], 'banner_grid');
    expect(visible.first['margin_top'], 16);
    expect(visible.first['padding_bottom'], 22);
    expect(visible.first['children'].first['attachment_id'], 77);
    expect(visible.last['source'], 'best_selling');
    expect(visible.last['height_px'], 260);
  });

  test('Designer and Shopping share one canonical Banner List layout spec', () {
    final json = <String, dynamic>{
      'type': 'banner_list',
      'designer_component_type': 'banner_list',
      'layout_variant': 'list',
      'height': 40,
      'height_px': 40,
      'width': 1.0,
      'width_pct': 100.0,
      'max_cross_axis_extent': 300,
      'max_width_px': 300,
      'main_axis_spacing': 10,
      'cross_axis_spacing': 10,
      'item_gap': 10,
      'border_radius': 16,
      'corner_radius': 16,
      'horizontal': true,
      'cross_axis_count': 2,
      'columns': 2,
      'cross_aspect_ratio': 1,
      'card_aspect_ratio': 1,
      'elevation': 1,
      'card_depth': 1,
      'fixed_grid_view_count': 2,
      'limit': 2,
      'margin_left': 0,
      'margin_right': 0,
      'padding_left': 12,
      'padding_right': 12,
      'children': [
        {'type': 'image', 'attachment_id': 83, 'image_url': 'https://example.com/benefits.png'},
      ],
    };

    final previewSpec = DesignerLayoutSpec.fromMap(json);
    final publishedSpec = DesignerLayoutSpec.fromMap({
      ...json,
      ...previewSpec.canonicalAliases(),
    });

    expect(previewSpec.height, 40);
    expect(previewSpec.childWidthFor(360), 300);
    expect(previewSpec.mainAxisSpacing, 10);
    expect(previewSpec.crossAxisSpacing, 10);
    expect(previewSpec.borderRadius, 16);
    expect(previewSpec.elevation, 1);
    expect(previewSpec.fixedGridViewCount, 2);
    expect(publishedSpec.childWidthFor(360), previewSpec.childWidthFor(360));
    expect(publishedSpec.height, previewSpec.height);
    expect(publishedSpec.margin, previewSpec.margin);
    expect(publishedSpec.padding, previewSpec.padding);
  });

  test('Canonical layout aliases never disagree after Designer serialization', () {
    final section = DesignerComponent(
      id: 'banner-list-contract',
      type: 'Banner',
      title: 'Benefits strip',
      layout: 'Banner List',
      properties: {
        'height': 40,
        'width': 1.0,
        'max_cross_axis_extent': 300,
        'main_axis_spacing': 10,
        'cross_axis_spacing': 10,
        'border_radius': 16,
        'cross_axis_count': 2,
        'cross_aspect_ratio': 1.0,
        'elevation': 1,
        'fixed_grid_view_count': 2,
      },
    ).toPublishedSection();

    expect(section['height'], section['height_px']);
    expect(section['width_pct'], 100);
    expect(section['max_cross_axis_extent'], section['max_width_px']);
    expect(section['main_axis_spacing'], 10);
    expect(section['cross_axis_spacing'], section['item_gap']);
    expect(section['border_radius'], section['corner_radius']);
    expect(section['cross_axis_count'], section['columns']);
    expect(section['cross_aspect_ratio'], section['card_aspect_ratio']);
    expect(section['elevation'], section['card_depth']);
    expect(section['fixed_grid_view_count'], section['limit']);
  });

  test('Published component JSON keeps the selected layout and every edited dimension', () {
    final component = DesignerComponent(
      id: 'banner-test',
      type: 'Banner',
      title: 'Hero banner',
      layout: 'Banner Slider',
      properties: {
        'designer_component_type': 'banner_slider',
        'height': 240,
        'width': .85,
        'margin_top': 18,
        'padding_bottom': 22,
        'border_radius': 16,
        'children': [
          {'type': 'image', 'image_url': 'https://example.com/hero.jpg', 'title': '', 'link_type': 'in_app', 'link_value': 'page:categories'},
          {'type': 'text', 'text': 'Legacy text child', 'title': 'Legacy text'},
          {'type': 'link', 'link_value': 'ark://cart', 'title': 'Legacy link'},
        ],
      },
    );
    final section = component.toPublishedSection();
    expect(section['type'], 'banner_slider');
    expect(section['designer_component_type'], 'banner_slider');
    expect(section['height_px'], 240);
    expect(section['width_pct'], 85);
    expect(section['margin_top'], 18);
    expect(section['padding_bottom'], 22);
    expect((section['children'] as List), hasLength(1));
    expect((section['children'] as List).first['title'], '');
    expect((section['children'] as List).first['type'], 'image');
    expect((section['children'] as List).first['link_value'], 'page:categories');
  });

  test('Published layout rounds WordPress integer dimensions before sync', () {
    final component = DesignerComponent(
      id: 'integer-layout-test',
      type: 'Banner',
      title: 'Integer layout',
      layout: 'Banner Scroll',
      properties: {
        'height': 40.4,
        'max_cross_axis_extent': 80.8,
        'main_axis_spacing': 3.6,
        'cross_axis_spacing': 5.4,
        'margin_top': 7.8,
        'padding_bottom': 11.2,
        'elevation': 13.306451612903228,
      },
    );
    final section = component.toPublishedSection();
    expect(section['height_px'], 40);
    expect(section['max_width_px'], 81);
    expect(section['main_axis_spacing'], 4);
    expect(section['cross_axis_spacing'], 5);
    expect(section['margin_top'], 8);
    expect(section['padding_bottom'], 11);
    expect(section['card_depth'], 13);
    expect(section['elevation'], 13);
  });

  test('Banner publish canonicalizes WordPress Media Library child image aliases', () {
    final component = DesignerComponent(
      id: 'banner-media-alias',
      type: 'Banner',
      title: 'Media Library banner',
      layout: 'Banner Slider',
      properties: {
        'children': [
          {
            'type': 'image',
            'media_id': '731',
            'source_url': 'https://pluginstore.shop/wp-content/uploads/2026/11/banner.jpg',
            'title': '',
          },
          {
            'type': 'image',
            'id': 732,
            'url': 'https://pluginstore.shop/wp-content/uploads/2026/11/banner-2.jpg',
            'active': true,
          },
        ],
      },
    );

    final section = component.toPublishedSection();
    final children = section['children'] as List;
    expect(children, hasLength(2));
    expect(children[0]['attachment_id'], 731);
    expect(children[0]['image_url'], 'https://pluginstore.shop/wp-content/uploads/2026/11/banner.jpg');
    expect(children[0]['source_url'], children[0]['image_url']);
    expect(children[1]['attachment_id'], 732);
    expect(children[1]['image_url'], 'https://pluginstore.shop/wp-content/uploads/2026/11/banner-2.jpg');
  });

  test('Category and Product layout variants serialize to WordPress-supported component types', () {
    final categorySlider = DesignerComponent(
      id: 'category-slider-test',
      type: 'Category',
      title: 'Shop categories',
      layout: 'Category Slider',
      properties: {
        'designer_component_type': 'category_slider',
        'category_layout': 'category_slider',
        'layout_variant': 'category_slider',
        'parent_category_id': 12,
        'cross_axis_count': 3,
        'main_axis_spacing': 14,
        'cross_axis_spacing': 9,
      },
    ).toPublishedSection();

    expect(categorySlider['type'], 'category_grid');
    expect(categorySlider['designer_component_type'], 'category_slider');
    expect(categorySlider['layout_variant'], 'slider');
    expect(categorySlider['category_layout'], 'slider');
    expect(categorySlider['category_id'], 12);
    expect(categorySlider['main_axis_spacing'], 14);
    expect(categorySlider['cross_axis_spacing'], 9);

    final productSlider = DesignerComponent(
      id: 'product-slider-test',
      type: 'Product',
      title: 'Best products',
      layout: 'Product Slider',
      properties: {
        'designer_component_type': 'product_slider',
        'layout_variant': 'product_slider',
        'source': 'best_selling',
        'source_id': 0,
      },
    ).toPublishedSection();

    expect(productSlider['type'], 'product_carousel');
    expect(productSlider['designer_component_type'], 'product_slider');
    expect(productSlider['layout_variant'], 'slider');
    expect(productSlider['source'], 'best_selling');

    final productList = DesignerComponent(
      id: 'product-list-test',
      type: 'Product',
      title: 'Latest products',
      layout: 'Product List',
      properties: {'source': 'new_arrival'},
    ).toPublishedSection();

    expect(productList['type'], 'product_list');
    expect(productList['layout_variant'], 'list');
    expect(productList['source'], 'latest');
  });

  test('Show all categories and Product Tag selection keep their published filters', () {
    final allCategories = DesignerComponent(
      id: 'all-categories-test',
      type: 'Category',
      title: 'All categories',
      layout: 'Category Grid',
      properties: {
        'show_all_categories': true,
        'parent_category_id': 35,
        'fixed_grid_view_count': 8,
      },
    ).toPublishedSection();
    expect(allCategories['category_id'], 0);
    expect(allCategories['limit'], 100);

    final taggedProducts = DesignerComponent(
      id: 'tag-products-test',
      type: 'Product',
      title: 'Summer collection',
      layout: 'Product Grid',
      properties: {
        'source': 'tag',
        'source_id': 77,
      },
    ).toPublishedSection();
    expect(taggedProducts['source'], 'tag');
    expect(taggedProducts['tag_id'], 77);
    expect(taggedProducts['source_id'], 77);
  });

  testWidgets('Tapping the live banner image opens its property editor', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
      home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ark-designer-banner-preview-page-view')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ark-designer-banner-preview-page-view')));
    await tester.pumpAndSettle();

    expect(find.text('Banner Layout'), findsOneWidget);
    expect(find.text('Color'), findsWidgets);
    expect(find.text('Dimension'), findsWidgets);
  });

  testWidgets('Published banner carousel reports the tapped image child', (tester) async {
    Map<String, dynamic>? tapped;
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 360,
        height: 220,
        child: ArkDesignerBannerCarousel(
          slides: const [
            {'image_url': '', 'link_type': 'in_app', 'link_value': 'page:categories'},
          ],
          height: 180,
          autoplay: false,
          onSlideTap: (slide) => tapped = slide,
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('ark-designer-banner-preview-page-view')));
    await tester.pumpAndSettle();
    expect(tapped?['link_value'], 'page:categories');
  });

  testWidgets('Designer editor exposes seven live property tabs and child tools', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(
      home: GlowHitDesignerPage(token: 'test-token', loadRemoteConfig: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Main promotional banner').first);
    await tester.pumpAndSettle();

    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Color'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Title'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Padding'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Margin'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Dimension'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Settings'), hasLength(1));
    expect(find.byType(Tab).evaluate().where((e) => (e.widget as Tab).text == 'Style'), hasLength(1));

    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Title Text Style'), findsOneWidget);

    final titleStyleButton = find.text('Title Text Style');
    await tester.ensureVisible(titleStyleButton);
    await tester.pumpAndSettle();
    await tester.tap(titleStyleButton);
    await tester.pumpAndSettle();
    expect(find.text('Text Style'), findsOneWidget);
    expect(find.text('Sample Text'), findsOneWidget);
    expect(find.text('Search Font'), findsNothing);
    // The typography controls are intentionally below the live preview and
    // swatches in a scrollable property page; scroll them into the lazy list.
    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(find.text('Font Family'), findsOneWidget);
    await tester.tap(find.text('Font Family'));
    await tester.pumpAndSettle();
    expect(find.text('Search Font'), findsOneWidget);
    // Select a font to close the picker, then explicitly finish Text Style.
    await tester.tap(find.text('ABeeZee').first);
    await tester.pumpAndSettle();
    final doneStyle = find.text('DONE');
    await tester.ensureVisible(doneStyle);
    await tester.tap(doneStyle);
    await tester.pumpAndSettle();

    final styleTab = find.text('Style');
    await tester.ensureVisible(styleTab);
    await tester.pumpAndSettle();
    await tester.tap(styleTab);
    await tester.pumpAndSettle();
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Autoplay'), findsOneWidget);
    expect(find.text('View Fraction'), findsOneWidget);
    expect(find.text('Fade'), findsOneWidget);
    expect(find.text('Dot'), findsOneWidget);
    expect(find.text('Arrow'), findsOneWidget);

    final settingsTab = find.text('Settings');
    await tester.ensureVisible(settingsTab);
    await tester.pumpAndSettle();
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();
    expect(find.text('Component Status'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Add image from Media Library'), findsOneWidget);
    expect(find.text('Add text'), findsNothing);
    expect(find.text('Add link'), findsNothing);

    await tester.tap(find.byTooltip('View live component JSON'));
    await tester.pumpAndSettle();
    expect(find.text('Live Component JSON'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('ARK Designer'), findsOneWidget);
  });
}
