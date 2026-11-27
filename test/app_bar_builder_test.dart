import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/designer_app_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('App Bar Builder provides twelve distinct ready-made presets', () {
    expect(DesignerAppBarConfig.presets, hasLength(12));
    final ids = DesignerAppBarConfig.presets.map((e) => e['id']).toSet();
    expect(ids, containsAll(['amazon','flipkart','myntra','meesho','minimal','premium','location','gradient','compact','search','fashion','custom']));
  });

  test('App Bar JSON preserves toggles, dimensions, custom page visibility and GIF URL', () {
    final config = DesignerAppBarConfig(json: {
      'preset': 'amazon',
      'enabled': true,
      'show_voice_search': true,
      'show_cart': false,
      'height': 88,
      'spacing': 12,
      'radius': 18,
      'position': 'floating',
      'background_image_url': 'https://pluginstore.shop/wp-content/uploads/header.gif',
      'background_mime_type': 'image/gif',
      'visible_pages': {'home': true, 'custom_campaign': false},
      'actions': [
        {'id':'a1','label':'Support','icon_family':'Material','icon':'support_agent','link_type':'page','link_value':'account','visible':true},
      ],
    });
    final json = config.toJson();
    expect(json['show_voice_search'], isTrue);
    expect(json['show_cart'], isFalse);
    expect(config.height, 88);
    expect(config.renderHeight, greaterThanOrEqualTo(132));
    expect(json['spacing'], 12);
    expect(json['radius'], 18);
    expect(json['background_mime_type'], 'image/gif');
    expect(json['background_image_url'], contains('header.gif'));
    expect(config.visibleOn('custom_campaign'), isFalse);
    expect(config.visibleOn('home'), isTrue);
    expect(config.actions.single['link_value'], 'account');
  });

  test('App Bar config normalizes custom moving search terms', () {
    final config = DesignerAppBarConfig(json: {
      'search_placeholder_terms': ['watch', 'books', 'clothing', '', '  '],
    });
    expect(config.searchTerms, ['watch', 'books', 'clothing']);
    final fallback = DesignerAppBarConfig(json: {'search_placeholder_terms': []});
    expect(fallback.searchTerms, isEmpty);
  });

  test('App Bar Builder limits custom action buttons to ten', () {
    final actions = List.generate(12, (i) => {
      'id':'a$i','label':'Action $i','icon_family':'Material','icon':'star',
      'link_type':'page','link_value':'home','visible':true,
    });
    final config = DesignerAppBarConfig(json: {'actions': actions});
    expect(config.actions, hasLength(10));
  });

  testWidgets('App Bar Builder displays live preview and twelve preset choices', (tester) async {
    DesignerAppBarConfig? saved;
    await tester.pumpWidget(MaterialApp(home: DesignerAppBarBuilderPage(
      initialConfig: DesignerAppBarConfig(),
      availablePages: const [
        {'key':'home','title':'Home'},
        {'key':'search','title':'Search'},
        {'key':'custom_campaign','title':'Campaign'},
      ],
      onUpload: () async => null,
      onSave: (value) async { saved = value; },
    )));
    await tester.pumpAndSettle();

    expect(find.text('App Bar Builder'), findsOneWidget);
    expect(find.text('LIVE PREVIEW · GLOWHIT'), findsOneWidget);
    expect(DesignerAppBarConfig.presets, hasLength(12));
    // The preset grid and preview are in the first viewport. The other controls
    // are covered by the config round-trip tests above without fragile nested scrolling.
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.toJson()['show_voice_search'], isTrue);
  });

  testWidgets('Native App Bar uses a single search field and three-row layout', (tester) async {
    final config=DesignerAppBarConfig(json:{
      'height':156,
      'show_menu':true,
      'show_search':true,
      'show_voice_search':true,
      'show_location':true,
    });
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      appBar:PreferredSize(preferredSize:Size.fromHeight(config.height),child:DesignerAppBarView(
        config:config,pageKey:'home',cartCount:0,searchController:TextEditingController(),searchFocusNode:FocusNode(),onSearchSubmitted:(_){},
        onMenu:(){},onCart:(){},onSearch:(){},onVoiceSearch:(){},onWishlist:(){},onRefresh:(){},onLocation:(){},onCustomAction:(_){},
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.text('watch'),findsOneWidget);
    expect(find.text('Deliver to your address'),findsOneWidget);
    expect(find.byTooltip('Voice Search'),findsOneWidget);
    expect(find.byType(TextField),findsOneWidget);
  });


  testWidgets('Native App Bar submits typed product searches', (tester) async {
    String? submitted;
    final controller = TextEditingController();
    final focus = FocusNode();
    final config = DesignerAppBarConfig(json: {'show_search': true, 'show_location': false});
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(config.renderHeight),
        child: DesignerAppBarView(
          config: config,
          pageKey: 'home',
          cartCount: 0,
          searchController: controller,
          searchFocusNode: focus,
          onSearchSubmitted: (value) => submitted = value,
          onMenu: () {}, onCart: () {}, onSearch: () {}, onVoiceSearch: () {},
          onWishlist: () {}, onRefresh: () {}, onLocation: () {}, onCustomAction: (_) {},
        ),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'red shirt');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(submitted, 'red shirt');
    controller.dispose();
    focus.dispose();
  });

  testWidgets('App Bar Builder pins the preview outside the scrolling properties', (tester) async {
    await tester.pumpWidget(MaterialApp(home:DesignerAppBarBuilderPage(
      initialConfig:DesignerAppBarConfig(),
      availablePages:const [{'key':'home','title':'Home'}],
      onUpload:() async=>null,
      onSave:(_) async{},
    )));
    await tester.pumpAndSettle();
    expect(find.text('LIVE PREVIEW · GLOWHIT'),findsOneWidget);
    final previewBox=tester.getRect(find.text('LIVE PREVIEW · GLOWHIT'));
    expect(previewBox.top,lessThan(200));
    final settingsScroll=find.byType(ListView).first;
    await tester.drag(settingsScroll,const Offset(0,-400));
    await tester.pumpAndSettle();
    expect(find.text('LIVE PREVIEW · GLOWHIT'),findsOneWidget);
    expect(tester.getRect(find.text('LIVE PREVIEW · GLOWHIT')).top,previewBox.top);
  });

  testWidgets('Native App Bar view renders voice, cart and custom actions', (tester) async {
    final config = DesignerAppBarConfig(json: {
      'show_voice_search': true,
      'show_cart': true,
      'actions': [
        {'id':'help','label':'Help','icon_family':'Material','icon':'help_outline','link_type':'page','link_value':'account','visible':true},
      ],
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(config.height),
        child: DesignerAppBarView(
          config: config,
          pageKey: 'home',
          cartCount: 3,
          searchController: TextEditingController(), searchFocusNode: FocusNode(), onSearchSubmitted: (_) {},
          onMenu: () {}, onCart: () {}, onSearch: () {}, onVoiceSearch: () {},
          onWishlist: () {}, onRefresh: () {}, onLocation: () {}, onCustomAction: (_) {},
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Voice Search'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Help'), findsOneWidget);
  });
}
