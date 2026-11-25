import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/glowhit_designer_page.dart';
import 'package:glowhit_shopping/designer_banner_carousel.dart';
import 'package:glowhit_shopping/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GlowHit remains configured for the live WooCommerce store', () {
    expect(storeUrl, 'https://pluginstore.shop');
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
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add component'), findsOneWidget);
    expect(find.text('Banner'), findsWidgets);
    expect(find.text('Category'), findsWidgets);
    expect(find.text('Product'), findsWidgets);
    await tester.tap(find.text('Banner').last);
    await tester.pumpAndSettle();
    expect(find.text('Banner Grid'), findsOneWidget);
    expect(find.text('Banner Slider'), findsOneWidget);
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
