import 'dart:async';

import 'package:flutter/material.dart';
import 'designer_app_bar_menu_editor.dart';
import 'designer_navigation_bar.dart';

const _appBarAccent = Color(0xFF5B3A9E);

class DesignerAppBarConfig {
  DesignerAppBarConfig({Map<String, dynamic>? json}) : _json = _normalize(json ?? const {});
  final Map<String, dynamic> _json;
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_json);
  bool get enabled => _json['enabled'] != false;
  double get height => ((_json['height'] as num?)?.toDouble() ?? 72).clamp(88.0,220.0).toDouble();
  double get renderHeight {
    final minimum = 50.0 + (show('show_search') ? 50.0 : 0.0) + (show('show_location') ? 32.0 : 0.0);
    return height < minimum ? minimum : height;
  }
  double get spacing => ((_json['spacing'] as num?)?.toDouble() ?? 8).clamp(0.0,32.0).toDouble();
  double get radius => ((_json['radius'] as num?)?.toDouble() ?? 12).clamp(0.0,36.0).toDouble();
  String get preset => (_json['preset'] ?? 'custom').toString();
  String get position => (_json['position'] ?? 'top').toString();
  String get backgroundImageUrl => (_json['background_image_url'] ?? '').toString();
  String get logoUrl => (_json['logo_url'] ?? '').toString();
  String get menuHeaderImageUrl => (_json['menu_header_image_url'] ?? '').toString();
  int get menuHeaderImageId => (_json['menu_header_image_id'] as num?)?.toInt() ?? int.tryParse((_json['menu_header_image_id'] ?? '0').toString()) ?? 0;
  int get backgroundImageId => (_json['background_image_id'] as num?)?.toInt() ?? int.tryParse((_json['background_image_id'] ?? '0').toString()) ?? 0;
  String get addressTextColor => (_json['address_text_color'] ?? '#202124').toString();
  bool get extendUnderStatusBar => _json['extend_under_status_bar'] != false;
  String get statusBarBackground => (_json['status_bar_background'] ?? _json['background_color'] ?? '#FFFFFF').toString();
  String get statusBarIconBrightness => (_json['status_bar_icon_brightness'] ?? 'dark').toString() == 'light' ? 'light' : 'dark';
  static const defaultMenuItems = <Map<String,dynamic>>[
    {'id':'home','title':'Home','link_type':'page','link_value':'home','leading_icon_family':'Material','leading_icon':'home_outlined','leading_icon_style':'plain','trailing_icon_family':'Material','trailing_icon':'','visible':true,'admin_only':false},
    {'id':'categories','title':'Categories','link_type':'page','link_value':'categories','leading_icon_family':'Material','leading_icon':'grid_view','leading_icon_style':'plain','trailing_icon_family':'Material','trailing_icon':'','visible':true,'admin_only':false},
    {'id':'wishlist','title':'Wishlist','link_type':'page','link_value':'wishlist','leading_icon_family':'Material','leading_icon':'favorite_border','leading_icon_style':'plain','trailing_icon_family':'Material','trailing_icon':'','visible':true,'admin_only':false},
    {'id':'cart','title':'Cart','link_type':'page','link_value':'cart','leading_icon_family':'Material','leading_icon':'shopping_cart_outlined','leading_icon_style':'plain','trailing_icon_family':'Material','trailing_icon':'','visible':true,'admin_only':false},
    {'id':'account','title':'Account','link_type':'page','link_value':'account','leading_icon_family':'Material','leading_icon':'person_outline','leading_icon_style':'plain','trailing_icon_family':'Material','trailing_icon':'','visible':true,'admin_only':false},
    {'id':'ark-designer','title':'ARK Designer','link_type':'deep_link','link_value':'ark_designer','leading_icon_family':'Material','leading_icon':'design_services','leading_icon_style':'plain','trailing_icon_family':'Material','trailing_icon':'chevron_right','visible':true,'admin_only':true},
  ];
  List<Map<String,dynamic>> get menuItems => (_json['menu_items'] as List? ?? defaultMenuItems).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).take(30).toList();
  double get iconSize => ((_json['icon_size'] as num?)?.toDouble() ?? 22).clamp(16.0,36.0).toDouble();
  double get horizontalPadding => ((_json['horizontal_padding'] as num?)?.toDouble() ?? 10).clamp(0.0,24.0).toDouble();
  double get leftPadding => ((_json['left_padding'] as num?)?.toDouble() ?? horizontalPadding).clamp(0.0,24.0).toDouble();
  double get rightPadding => ((_json['right_padding'] as num?)?.toDouble() ?? horizontalPadding).clamp(0.0,24.0).toDouble();
  List<String> get searchTerms => (_json['search_placeholder_terms'] as List? ?? const ['watch','book','cloth']).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).take(12).toList();
  bool show(String key) => _json[key] != false;
  bool visibleOn(String page) => (_json['visible_pages'] as Map?)?[page] != false;
  List<Map<String,dynamic>> get actions => (_json['actions'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).take(10).toList();

  static const pageKeys = ['home','search','categories','wishlist','product','account','cart','orders','notifications'];
  static const defaults = <String,dynamic>{
    'version':1,'enabled':true,'preset':'custom','background_color':'#FFFFFF','foreground_color':'#202124',
    'background_image_url':'','background_image_id':0,'background_mime_type':'','logo_url':'','menu_header_image_url':'','menu_header_image_id':0,'menu_items':defaultMenuItems,'address_text_color':'#202124','extend_under_status_bar':true,'status_bar_background':'#FFFFFF','status_bar_icon_brightness':'dark','icon_size':22.0,'horizontal_padding':10.0,'left_padding':10.0,'right_padding':10.0,'height':156.0,'spacing':8.0,'radius':12.0,'position':'top',
    'show_menu':true,'show_logo':true,'show_cart':true,'show_voice_search':true,'show_search':true,'show_wishlist':true ,'show_refresh':false,'show_location':true,
    'search_placeholder':'Search products...',
    'search_placeholder_terms':<String>['watch','book','cloth'],
    'menu_icon_family':'Material','menu_icon':'menu','cart_icon_family':'Material','cart_icon':'shopping_cart_outlined',
    'voice_icon_family':'Material','voice_icon':'mic_none','search_icon_family':'Material','search_icon':'search',
    'wishlist_icon_family':'Material','wishlist_icon':'favorite_border','refresh_icon_family':'Material','refresh_icon':'refresh',
    'location_icon_family':'Material','location_icon':'location_on_outlined','visible_pages':<String,dynamic>{},'actions':<dynamic>[],
    'menu_label':'GlowHit','search_background_color':'#FFFFFF','search_foreground_color':'#555555',
  };

  static Map<String,dynamic> _normalize(Map<String,dynamic> source) {
    final out=<String,dynamic>{...defaults,...source};
    final visibility=source['visible_pages'];
    final custom=visibility is Map ? visibility.keys.map((e)=>e.toString()).where((e)=>RegExp(r'^custom_[a-z0-9_]{1,40}$').hasMatch(e)).toList() : <String>[];
    out['visible_pages'] = <String,dynamic>{for(final page in [...pageKeys,...custom]) page: visibility is Map ? visibility[page]!=false : true};
    List<Map<String,dynamic>> normalizeActions(dynamic raw) => raw is List ? raw.whereType<Map>().take(10).map((e)=><String,dynamic>{
      'id':(e['id']??'').toString(),'label':(e['label']??'Action').toString(),
      'icon_family':(e['icon_family']??'Material').toString(),'icon':(e['icon']??'star_outline').toString(),
      'link_type':(e['link_type']??'page').toString(),'link_value':(e['link_value']??'home').toString(),'visible':e['visible']!=false,
    }).toList() : <Map<String,dynamic>>[];
    out['actions']=normalizeActions(source['actions']);
    final rawMenu = source['menu_items'];
    final menuSource = rawMenu is List && rawMenu.isNotEmpty ? rawMenu : defaultMenuItems;
    out['menu_items'] = menuSource.whereType<Map>().take(30).map((e)=><String,dynamic>{
      'id':(e['id']??DateTime.now().microsecondsSinceEpoch).toString(),
      'title':(e['title']??'Menu item').toString(),
      'link_type':(e['link_type']??'page').toString(),
      'link_value':(e['link_value']??'home').toString(),
      'leading_icon_family':(e['leading_icon_family']??'Material').toString(),
      'leading_icon':(e['leading_icon']??'home_outlined').toString(),
      'leading_icon_style':(e['leading_icon_style']??'plain').toString(),
      'trailing_icon_family':(e['trailing_icon_family']??'Material').toString(),
      'trailing_icon':(e['trailing_icon']??'chevron_right').toString(),
      'visible':e['visible']!=false,
      'admin_only':e['admin_only']==true,
    }).toList();
    out['menu_header_image_id'] = (source['menu_header_image_id'] as num?)?.toInt() ?? int.tryParse((source['menu_header_image_id'] ?? '0').toString()) ?? 0;
    out['background_image_id'] = (source['background_image_id'] as num?)?.toInt() ?? int.tryParse((source['background_image_id'] ?? '0').toString()) ?? 0;
    out['address_text_color'] = _validHex(source['address_text_color']) ? source['address_text_color'] : '#202124';
    out['extend_under_status_bar'] = source['extend_under_status_bar'] != false;
    out['status_bar_background'] = _validHex(source['status_bar_background']) ? source['status_bar_background'] : out['background_color'];
    out['status_bar_icon_brightness'] = source['status_bar_icon_brightness'] == 'light' ? 'light' : 'dark';
    out['icon_size']=((out['icon_size'] as num?)?.toDouble()??22).clamp(16.0,36.0).toDouble();
    out['horizontal_padding']=((out['horizontal_padding'] as num?)?.toDouble()??10).clamp(0.0,24.0).toDouble();
    final terms = source['search_placeholder_terms'];
    out['search_placeholder_terms'] = terms is List ? terms.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).take(12).toList() : <String>['watch','book','cloth'];
    out['height']=((out['height'] as num?)?.toDouble()??156).clamp(88.0,220.0).toDouble();
    out['spacing']=((out['spacing'] as num?)?.toDouble()??8).clamp(0.0,32.0).toDouble();
    out['radius']=((out['radius'] as num?)?.toDouble()??12).clamp(0.0,36.0).toDouble();
    out['position']=['top','floating','overlay'].contains(out['position'])?out['position']:'top';
    return out;
  }

  static bool _validHex(dynamic value) => value is String && RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(value);
  static Color color(String value,{Color fallback=Colors.white}) {
    final raw=value.replaceFirst('#',''); final parsed=int.tryParse(raw,radix:16);
    return parsed==null?fallback:Color(raw.length==6?0xFF000000|parsed:parsed);
  }

  static const presets=<Map<String,dynamic>>[
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
}

class DesignerAppBarBuilderPage extends StatefulWidget {
  const DesignerAppBarBuilderPage({super.key,required this.initialConfig,required this.availablePages,required this.onUpload,required this.onChooseMedia,required this.onSave});
  final DesignerAppBarConfig initialConfig;
  final List<Map<String,String>> availablePages;
  final Future<Map<String,dynamic>?> Function() onUpload;
  final Future<Map<String,dynamic>?> Function() onChooseMedia;
  final Future<void> Function(DesignerAppBarConfig) onSave;
  @override State<DesignerAppBarBuilderPage> createState()=>_DesignerAppBarBuilderPageState();
}

class _DesignerAppBarBuilderPageState extends State<DesignerAppBarBuilderPage> {
  late Map<String,dynamic> data;
  final colorController=TextEditingController();
  final placeholderController=TextEditingController();
  final searchTermsController=TextEditingController();
  final previewController=TextEditingController();
  final FocusNode previewFocusNode=FocusNode();
  final ScrollController settingsScrollController=ScrollController();
  bool uploading=false;

  @override void initState(){
    super.initState(); data=widget.initialConfig.toJson();
    final visibility=Map<String,dynamic>.from(data['visible_pages'] as Map? ?? {});
    for(final page in widget.availablePages){final key=page['key']??'home';visibility.putIfAbsent(key,()=>true);}
    data['visible_pages']=visibility;
    colorController.text=(data['background_color']??'#FFFFFF').toString();
    placeholderController.text=(data['search_placeholder']??'Search products...').toString();
    searchTermsController.text=configTermsText(data['search_placeholder_terms']);
  }
  String configTermsText(dynamic value) => value is List ? value.map((e)=>e.toString()).join(', ') : 'watch, book, cloth';
  @override void dispose(){colorController.dispose();placeholderController.dispose();searchTermsController.dispose();previewController.dispose();previewFocusNode.dispose();settingsScrollController.dispose();super.dispose();}
  void setValue(String key,dynamic value)=>setState(()=>data[key]=value);
  Future<void> apply() async { await widget.onSave(DesignerAppBarConfig(json:data)); if(mounted) Navigator.pop(context); }
  void _applyMedia(String key,Map<String,dynamic> media) {
    final url=(media['source_url']??media['url']??'').toString();if(url.isEmpty)return;
    final idValue=media['id']??media['attachment_id']??0;
    final id=idValue is num?idValue.toInt():int.tryParse(idValue.toString())??0;
    setState((){data[key]=url;if(key=='background_image_url'){data['background_image_id']=id;data['background_mime_type']=(media['mime_type']??'').toString();}if(key=='menu_header_image_url')data['menu_header_image_id']=id;});
  }
  Future<void> upload(String key) async {if(uploading)return;setState(()=>uploading=true);try{final media=await widget.onUpload();if(media!=null&&mounted)_applyMedia(key,media);}finally{if(mounted)setState(()=>uploading=false);}}
  Future<void> chooseExistingMedia(String key) async {if(uploading)return;setState(()=>uploading=true);try{final media=await widget.onChooseMedia();if(media!=null&&mounted)_applyMedia(key,media);}finally{if(mounted)setState(()=>uploading=false);}}
  void removeMedia(String key){setState((){data[key]='';if(key=='background_image_url'){data['background_image_id']=0;data['background_mime_type']='';}if(key=='menu_header_image_url')data['menu_header_image_id']=0;});}
    Future<NavIconChoice?> pickIcon() => showDialog<NavIconChoice>(context:context,builder:(_)=>const _AppBarIconPicker());
  Future<void> chooseIcon(String key) async {
    final choice=await pickIcon();if(choice==null||!mounted)return;
    setState(() { data['${key}_family']=choice.family; data[key]=choice.name; });
  }
  Future<void> addAction() async {
    final actions=DesignerAppBarConfig(json:data).actions;
    if(actions.length>=10){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Maximum 10 custom actions allowed.')));return;}
    actions.add({'id':DateTime.now().microsecondsSinceEpoch.toString(),'label':'Action ${actions.length+1}','icon_family':'Material','icon':'star_outline','link_type':'page','link_value':'home','visible':true});
    setValue('actions',actions);
  }
  Future<void> openMenuEditor() async {
    final config=DesignerAppBarConfig(json:data);
    final result=await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder:(_)=>DesignerAppBarMenuEditorPage(initialItems:config.menuItems,initialImageUrl:config.menuHeaderImageUrl,initialImageId:config.menuHeaderImageId,onUpload:widget.onUpload,onChooseMedia:widget.onChooseMedia)));
    if(result==null||!mounted)return;
    setState((){data['menu_items']=result['menu_items'] is List?result['menu_items']:DesignerAppBarConfig.defaultMenuItems;data['menu_header_image_url']=(result['menu_header_image_url']??'').toString();data['menu_header_image_id']=(result['menu_header_image_id'] as num?)?.toInt()??0;});
  }
  Widget menuEditor()=>Card(child:Padding(padding:const EdgeInsets.all(12),child:ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.menu_open,color:_appBarAccent),title:const Text('Menu Edit',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${DesignerAppBarConfig(json:data).menuItems.length} menu items · WordPress Media Library image'),trailing:const Icon(Icons.chevron_right),onTap:openMenuEditor))));
    Future<void> editActionIcon(int index) async {
    final choice=await pickIcon();if(choice==null||!mounted)return;
    final actions=DesignerAppBarConfig(json:data).actions;actions[index]['icon_family']=choice.family;actions[index]['icon']=choice.name;setValue('actions',actions);
  }
  Future<void> _pickColor(String key,String title) async {
    final current=DesignerAppBarConfig.color((data[key]??'#FFFFFF').toString());var hsv=HSVColor.fromColor(current);
    final picked=await showDialog<Color>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialogState)=>AlertDialog(
      title:Text(title),content:SizedBox(width:320,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(height:54,width:double.infinity,decoration:BoxDecoration(color:hsv.toColor(),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.black12))),
        const SizedBox(height:14),const Text('Hue'),Slider(value:hsv.hue.clamp(0,360).toDouble(),min:0,max:360,divisions:360,onChanged:(v)=>setDialogState(()=>hsv=hsv.withHue(v))),
        const Text('Saturation'),Slider(value:hsv.saturation,min:0,max:1,divisions:100,onChanged:(v)=>setDialogState(()=>hsv=hsv.withSaturation(v))),
        const Text('Brightness'),Slider(value:hsv.value,min:0,max:1,divisions:100,onChanged:(v)=>setDialogState(()=>hsv=hsv.withValue(v))),
        Text('#'+hsv.toColor().value.toRadixString(16).substring(2).toUpperCase(),style:const TextStyle(fontWeight:FontWeight.w800)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,hsv.toColor()),child:const Text('Use Colour'))],
    )));
    if(picked==null||!mounted)return;final hex='#'+picked.value.toRadixString(16).substring(2).toUpperCase();setState(()=>data[key]=hex);if(key=='background_color')colorController.text=hex;
  }
  Widget _colorPickerTile(String key,String title)=>ListTile(contentPadding:EdgeInsets.zero,title:Text(title),subtitle:Text((data[key]??'#FFFFFF').toString()),leading:Container(width:28,height:28,decoration:BoxDecoration(color:DesignerAppBarConfig.color((data[key]??'#FFFFFF').toString()),shape:BoxShape.circle,border:Border.all(color:Colors.black26))),trailing:const Icon(Icons.palette_outlined),onTap:()=>_pickColor(key,'Choose $title'));
  Widget backgroundColorPicker()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Background colour'),const SizedBox(height:7),InkWell(onTap:()=>_pickColor('background_color','Choose App Bar Background'),child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),decoration:BoxDecoration(border:Border.all(color:Colors.black26),borderRadius:BorderRadius.circular(10)),child:Row(children:[Container(width:28,height:28,decoration:BoxDecoration(color:DesignerAppBarConfig.color((data['background_color']??'#FFFFFF').toString()),borderRadius:BorderRadius.circular(6),border:Border.all(color:Colors.black26))),const SizedBox(width:10),Expanded(child:Text((data['background_color']??'#FFFFFF').toString(),style:const TextStyle(fontWeight:FontWeight.w700))),const Icon(Icons.palette_outlined)])))]);
    Widget switchTile(String key,String title,IconData icon)=>SwitchListTile(contentPadding:EdgeInsets.zero,secondary:Icon(icon,color:_appBarAccent),title:Text(title),value:data[key]!=false,onChanged:(v)=>setValue(key,v));
  Widget slider(String title,String key,double min,double max){
    final value=((data[key] as num?)?.toDouble()??min).clamp(min,max).toDouble();
    return Column(children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(title),Text(value.toStringAsFixed(0))]),Slider(value:value,min:min,max:max,divisions:(max-min).round(),onChanged:(v)=>setValue(key,v))]);
  }
  Widget presetTile(Map<String,dynamic> preset){
    final selected=data['preset']==preset['id'];
    final bg=DesignerAppBarConfig.color(preset['background_color'].toString());
    final fg=DesignerAppBarConfig.color(preset['foreground_color'].toString(),fallback:Colors.black);
    return InkWell(onTap:()=>setState(() { data.addAll(preset); data['preset']=preset['id']; colorController.text=data['background_color'].toString(); }),child:Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(border:Border.all(color:selected?_appBarAccent:Colors.black12,width:selected?2:1),borderRadius:BorderRadius.circular(12)),child:Column(children:[
      Container(height:32,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(7)),child:Row(children:[Icon(Icons.menu,size:15,color:fg),const SizedBox(width:5),Expanded(child:Container(height:15,decoration:BoxDecoration(color:fg.withOpacity(.13),borderRadius:BorderRadius.circular(12)))),Icon(Icons.shopping_cart_outlined,size:15,color:fg)])),
      const SizedBox(height:5),Text(preset['name'].toString(),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
    ])));
  }
  Widget preview(){
    final config=DesignerAppBarConfig(json:data);
    return ClipRRect(borderRadius:BorderRadius.circular(14),child:Column(children:[
      Container(width:double.infinity,padding:const EdgeInsets.all(6),color:Colors.black12,child:const Text('LIVE PREVIEW · GLOWHIT',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold))),
      SizedBox(height:22,width:double.infinity,child:Stack(fit:StackFit.expand,children:[if(config.extendUnderStatusBar&&config.backgroundImageUrl.isNotEmpty)Image.network(config.backgroundImageUrl,fit:BoxFit.cover,gaplessPlayback:true,errorBuilder:(_,__,___)=>ColoredBox(color:DesignerAppBarConfig.color(config.backgroundColor))),ColoredBox(color:config.extendUnderStatusBar?(config.backgroundImageUrl.isEmpty?DesignerAppBarConfig.color(config.backgroundColor):Colors.transparent):DesignerAppBarConfig.color(config.statusBarBackground)),Align(alignment:Alignment.centerLeft,child:Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Text('9:41  •  ▮▮▮  ▰',style:TextStyle(color:DesignerAppBarConfig.color(config.foregroundColor,fallback:Colors.black),fontSize:10))))])),
      SizedBox(height:config.renderHeight,child:DesignerAppBarView(config:config,pageKey:'home',cartCount:2,searchController:previewController,searchFocusNode:previewFocusNode,onSearchSubmitted:(_){},onMenu:(){},onCart:(){},onSearch:(){},onVoiceSearch:(){},onWishlist:(){},onRefresh:(){},onLocation:(){},onCustomAction:(_){ })),
    ]));
  }

  @override Widget build(BuildContext context){
    final config=DesignerAppBarConfig(json:data);
    final previewHeight=(config.renderHeight+50).clamp(150.0,270.0).toDouble();
    return Scaffold(
      resizeToAvoidBottomInset:true,
      appBar:AppBar(title:const Text('App Bar Builder'),actions:[TextButton(onPressed:apply,child:const Text('Apply'))]),
      body:Column(children:[
        // Pinned preview: it stays fixed while properties below scroll.
        SizedBox(height:previewHeight, child:Padding(padding:const EdgeInsets.fromLTRB(16,10,16,8),child:preview())),
        const Divider(height:1),
        Expanded(child:ListView(controller:settingsScrollController,padding:const EdgeInsets.fromLTRB(16,12,16,24),children:[
      const Text('12 Ready-made App Bars',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
      const SizedBox(height:9),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:DesignerAppBarConfig.presets.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:2.2,crossAxisSpacing:8,mainAxisSpacing:8),itemBuilder:(_,i)=>presetTile(DesignerAppBarConfig.presets[i])),
      const SizedBox(height:12),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Header Controls',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        switchTile('enabled','Enable App Bar',Icons.visibility_outlined),
        switchTile('show_menu','Menu',Icons.menu),switchTile('show_logo','Logo',Icons.image_outlined),
        switchTile('show_cart','Cart',Icons.shopping_cart_outlined),switchTile('show_voice_search','Voice Search',Icons.mic_none),
        switchTile('show_search','Search',Icons.search),switchTile('show_wishlist','Wishlist',Icons.favorite_border),
        switchTile('show_refresh','Refresh',Icons.refresh),switchTile('show_location','Address / Location',Icons.location_on_outlined),
        switchTile('extend_under_status_bar','Extend background into Status Bar',Icons.vertical_align_top),
        _colorPickerTile('address_text_color','Delivery Address Text Colour'),
        _colorPickerTile('status_bar_background','Status Bar Colour'),
        DropdownButtonFormField<String>(value:config.statusBarIconBrightness,decoration:const InputDecoration(labelText:'Status Bar Icon Brightness'),items:const [DropdownMenuItem(value:'dark',child:Text('Dark icons')),DropdownMenuItem(value:'light',child:Text('Light icons'))],onChanged:(v)=>setValue('status_bar_icon_brightness',v??'dark')),
      ]))),
      menuEditor(),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Icon Library',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        for(final item in [('menu_icon','Menu',Icons.menu),('cart_icon','Cart',Icons.shopping_cart_outlined),('voice_icon','Voice Search',Icons.mic_none),('search_icon','Search',Icons.search),('wishlist_icon','Wishlist',Icons.favorite_border),('refresh_icon','Refresh',Icons.refresh),('location_icon','Location',Icons.location_on_outlined)])
          ListTile(contentPadding:EdgeInsets.zero,leading:DesignerNavIcons.icon((data['${item.$1}_family']??'Material').toString(),(data[item.$1]??'').toString(),color:_appBarAccent),title:Text(item.$2),trailing:const Icon(Icons.chevron_right),onTap:()=>chooseIcon(item.$1)),
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Logo & Background',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.image_outlined),title:const Text('WordPress Media Library · Logo'),subtitle:Text(config.logoUrl.isEmpty?'No logo selected':'Logo selected · tap to replace'),onTap:uploading?null:()=>chooseExistingMedia('logo_url'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'Upload from phone',onPressed:uploading?null:()=>upload('logo_url'),icon:const Icon(Icons.add_photo_alternate_outlined)),if(config.logoUrl.isNotEmpty)IconButton(tooltip:'Delete logo',icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()=>removeMedia('logo_url'))])),
        ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.wallpaper_outlined),title:const Text('WordPress Media Library · Background Image / GIF'),subtitle:Text(config.backgroundImageUrl.isEmpty?'No background selected':'Background media selected · tap to replace'),onTap:uploading?null:()=>chooseExistingMedia('background_image_url'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'Upload from phone',onPressed:uploading?null:()=>upload('background_image_url'),icon:const Icon(Icons.add_photo_alternate_outlined)),if(config.backgroundImageUrl.isNotEmpty)IconButton(tooltip:'Delete background',icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()=>removeMedia('background_image_url'))])),
        if(uploading) const LinearProgressIndicator(),
        backgroundColorPicker(),
        TextField(controller:placeholderController,decoration:const InputDecoration(labelText:'Search placeholder'),onChanged:(v)=>setValue('search_placeholder',v)),
        TextField(controller:searchTermsController,decoration:const InputDecoration(labelText:'Moving search words (comma separated)',hintText:'watch, book, cloth'),onChanged:(v)=>setValue('search_placeholder_terms',v.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).take(12).toList())),
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Dimensions & Position',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        slider('Header Height','height',48,220),slider('Icon Size','icon_size',16,36),slider('Left Padding','left_padding',0,24),slider('Right Padding','right_padding',0,24),slider('Icon / Item Spacing','spacing',0,32),slider('Corner Radius','radius',0,36),
        DropdownButtonFormField<String>(value:config.position,decoration:const InputDecoration(labelText:'Header Position'),items:const [DropdownMenuItem(value:'top',child:Text('Top / Standard')),DropdownMenuItem(value:'floating',child:Text('Floating / Rounded')),DropdownMenuItem(value:'overlay',child:Text('Overlay Style'))],onChanged:(v)=>setValue('position',v??'top')),
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Page Visibility',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        for(final page in widget.availablePages) CheckboxListTile(contentPadding:EdgeInsets.zero,dense:true,title:Text(page['title']??page['key']??''),value:(data['visible_pages'] as Map?)?[page['key']]!=false,onChanged:(v){final map=Map<String,dynamic>.from(data['visible_pages'] as Map? ?? <String,dynamic>{});map[page['key']??'home']=v??true;setValue('visible_pages',map);}),
      ]))),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Custom Action Buttons',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),TextButton.icon(onPressed:config.actions.length>=10?null:addAction,icon:const Icon(Icons.add),label:const Text('Add'))]),
        Text('${config.actions.length}/10 actions'),
        for(var i=0;i<config.actions.length;i++) actionEditor(i,config.actions[i]),
      ]))),
      const SizedBox(height:16),
      SizedBox(height:50,child:FilledButton.icon(onPressed:apply,icon:const Icon(Icons.check),label:const Text('Apply Selected App Bar'))),
      const SizedBox(height:28),
        ])),
      ]),
    );
  }

  Widget actionEditor(int index,Map<String,dynamic> action){
    final actions=DesignerAppBarConfig(json:data).actions;
    return Card(margin:const EdgeInsets.only(top:8),child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      Row(children:[
        IconButton(onPressed:()=>editActionIcon(index),icon:DesignerNavIcons.icon((action['icon_family']??'Material').toString(),(action['icon']??'star_outline').toString(),color:_appBarAccent)),
        Expanded(child:TextFormField(initialValue:(action['label']??'Action').toString(),decoration:const InputDecoration(labelText:'Button label',isDense:true),onChanged:(v){actions[index]['label']=v;setValue('actions',actions);})),
        IconButton(onPressed:(){actions.removeAt(index);setValue('actions',actions);},icon:const Icon(Icons.delete_outline,color:Colors.red)),
      ]),
      DropdownButtonFormField<String>(value:(action['link_type']??'page').toString(),decoration:const InputDecoration(labelText:'Destination type'),items:const [DropdownMenuItem(value:'page',child:Text('App Page')),DropdownMenuItem(value:'url',child:Text('Website URL')),DropdownMenuItem(value:'deep_link',child:Text('App Deep Link'))],onChanged:(v){actions[index]['link_type']=v??'page';setValue('actions',actions);}),
      if((action['link_type']??'page')=='page')
        DropdownButtonFormField<String>(
          value: <String>{'home','search','categories','wishlist','cart','account','orders','notifications','product',...widget.availablePages.map((page)=>page['key']??'')}.contains((action['link_value']??'home').toString())?(action['link_value']??'home').toString():'home',
          decoration:const InputDecoration(labelText:'Destination App Page'),
          items: <String>{'home','search','categories','wishlist','cart','account','orders','notifications','product',...widget.availablePages.map((page)=>page['key']??'')}.where((value)=>value.isNotEmpty).map((value)=>DropdownMenuItem(value:value,child:Text(widget.availablePages.firstWhere((page)=>page['key']==value,orElse:()=>{'title':value})['title']??value))).toList(),
          onChanged:(v){actions[index]['link_value']=v??'home';setValue('actions',actions);},
        )
      else TextFormField(initialValue:(action['link_value']??'').toString(),decoration:InputDecoration(labelText:action['link_type']=='url'?'Website URL (https://...)':'App Deep Link (ark://...)'),onChanged:(v){actions[index]['link_value']=v;setValue('actions',actions);}),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Show this action'),value:action['visible']!=false,onChanged:(v){actions[index]['visible']=v;setValue('actions',actions);}),
    ])));
  }
}

class DesignerAppBarView extends StatelessWidget {
  const DesignerAppBarView({super.key,required this.config,required this.pageKey,required this.cartCount,required this.searchController,required this.searchFocusNode,required this.onSearchSubmitted,required this.onMenu,required this.onCart,required this.onSearch,required this.onVoiceSearch,required this.onWishlist,required this.onRefresh,required this.onLocation,required this.onCustomAction});
  final DesignerAppBarConfig config;final String pageKey;final int cartCount;final TextEditingController searchController;final FocusNode searchFocusNode;final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onMenu,onCart,onSearch,onVoiceSearch,onWishlist,onRefresh,onLocation;
  final ValueChanged<Map<String,dynamic>> onCustomAction;
  @override Widget build(BuildContext context){
    if(!config.enabled||!config.visibleOn(pageKey))return const SizedBox.shrink();
    final data=config.toJson();
    final fg=DesignerAppBarConfig.color((data['foreground_color']??'#202124').toString(),fallback:Colors.black);
    final bg=DesignerAppBarConfig.color((data['background_color']??'#FFFFFF').toString());
    Widget iconButton(String key,VoidCallback action,{bool badge=false}) {
      final family=(data['${key}_icon_family']??'Material').toString();
      final name=(data['${key}_icon']??'').toString();
      final icon=DesignerNavIcons.icon(family,name,color:fg,size:config.iconSize);
      return IconButton(
        visualDensity:VisualDensity.compact,
        constraints:const BoxConstraints(minWidth:40,minHeight:40),
        padding:EdgeInsets.zero,
        tooltip:key,
        onPressed:action,
        icon:badge?Badge(isLabelVisible:cartCount>0,label:Text('$cartCount'),child:icon):icon,
      );
    }
    Widget actionButton(Map<String,dynamic> action) => IconButton(
      visualDensity:VisualDensity.compact,
      constraints:const BoxConstraints(minWidth:38,minHeight:40),
      padding:EdgeInsets.zero,
      tooltip:(action['label']??'Action').toString(),
      onPressed:()=>onCustomAction(action),
      icon:DesignerNavIcons.icon((action['icon_family']??'Material').toString(),(action['icon']??'star_outline').toString(),color:fg,size:config.iconSize),
    );
    Widget searchField() => Container(
      height:46,
      decoration:BoxDecoration(
        color:DesignerAppBarConfig.color((data['search_background_color']??'#FFFFFF').toString()),
        borderRadius:BorderRadius.circular(config.radius),
      ),
      child:TextField(
        controller:searchController,
        focusNode:searchFocusNode,
        textInputAction:TextInputAction.search,
        onTap:onSearch,
        onSubmitted:onSearchSubmitted,
        style:TextStyle(color:DesignerAppBarConfig.color((data['search_foreground_color']??'#555555').toString()),fontSize:15),
        decoration:InputDecoration(
          isDense:true,
          hint: _RotatingSearchHint(terms: config.searchTerms.isEmpty ? [(data['search_placeholder']??'Search products...').toString()] : config.searchTerms, style: const TextStyle(color:Colors.black54,fontSize:14)),
          hintStyle:const TextStyle(color:Colors.black54,fontSize:14),
          prefixIcon:DesignerNavIcons.icon((data['search_icon_family']??'Material').toString(),(data['search_icon']??'search').toString(),color:Colors.black54,size:config.iconSize),
          prefixIconConstraints:const BoxConstraints(minWidth:44,minHeight:46),
          suffixIcon:Row(
            mainAxisSize:MainAxisSize.min,
            children:[
              if(config.show('show_voice_search')) IconButton(
                visualDensity:VisualDensity.compact,
                constraints:const BoxConstraints(minWidth:38,minHeight:40),
                padding:EdgeInsets.zero,
                tooltip:'Voice Search',
                onPressed:onVoiceSearch,
                icon:DesignerNavIcons.icon((data['voice_icon_family']??'Material').toString(),(data['voice_icon']??'mic_none').toString(),color:_appBarAccent,size:config.iconSize),
              ),
              IconButton(
                visualDensity:VisualDensity.compact,
                constraints:const BoxConstraints(minWidth:38,minHeight:40),
                padding:EdgeInsets.zero,
                tooltip:'Clear search',
                onPressed:(){
                  searchController.clear();
                  searchFocusNode.unfocus();
                },
                icon:const Icon(Icons.close,color:Colors.black54),
              ),
            ],
          ),
          border:InputBorder.none,
          contentPadding:const EdgeInsets.only(left:0,right:6,top:12,bottom:12),
        ),
      ),
    );
    final imageProvider=config.backgroundImageUrl.isEmpty?null:NetworkImage(config.backgroundImageUrl);
    final topRow=Row(children:[
      if(config.show('show_menu')) IconButton(
        visualDensity:VisualDensity.compact,
        constraints:const BoxConstraints(minWidth:40,minHeight:40),
        padding:EdgeInsets.zero,
        tooltip:'Menu',
        onPressed:onMenu,
        icon:DesignerNavIcons.icon((data['menu_icon_family']??'Material').toString(),(data['menu_icon']??'menu').toString(),color:fg,size:config.iconSize),
      ),
      if(config.show('show_logo')) ...[
        if(config.logoUrl.isNotEmpty) ClipRRect(borderRadius:BorderRadius.circular(6),child:Image.network(config.logoUrl,width:36,height:36,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
        const SizedBox(width:8),
        Flexible(child:Text((data['menu_label']??'GlowHit').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:17,fontWeight:FontWeight.w800))),
      ],
      const Spacer(),
      if(config.show('show_wishlist')) iconButton('wishlist',onWishlist),
      if(config.show('show_cart')) iconButton('cart',onCart,badge:true),
      if(config.show('show_refresh')) iconButton('refresh',onRefresh),
      if(config.actions.where((a)=>a['visible']!=false).isNotEmpty)
        Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(mainAxisSize:MainAxisSize.min,children:config.actions.where((a)=>a['visible']!=false).map(actionButton).toList()))),
    ]);
    final body=Container(
      padding:EdgeInsets.only(left:config.leftPadding,right:config.rightPadding,top:5,bottom:5),
      decoration:BoxDecoration(
        color:imageProvider==null?bg:Colors.transparent,
        borderRadius:BorderRadius.circular(config.position=='floating'?config.radius:0),
        boxShadow:config.position=='floating'?[BoxShadow(color:Colors.black.withOpacity(.12),blurRadius:10,offset:const Offset(0,3))]:null,
      ),
      child:Column(
        mainAxisSize:MainAxisSize.min,
        children:[
          SizedBox(height:40,child:topRow),
          if(config.show('show_search')) Padding(padding:const EdgeInsets.only(top:4),child:searchField()),
          if(config.show('show_location')) Padding(
            padding:const EdgeInsets.only(top:4),
            child:InkWell(
              onTap:onLocation,
              borderRadius:BorderRadius.circular(8),
              child:Padding(
                padding:const EdgeInsets.symmetric(horizontal:3,vertical:4),
                child:Row(children:[
                  DesignerNavIcons.icon((data['location_icon_family']??'Material').toString(),(data['location_icon']??'location_on_outlined').toString(),color:fg,size:config.iconSize),
                  const SizedBox(width:6),
                  Expanded(child:Text((data['address_label']??'Deliver to your address').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:DesignerAppBarConfig.color(config.addressTextColor,fallback:Colors.black),fontSize:14,fontWeight:FontWeight.w800,height:1.15))),
                  Icon(Icons.chevron_right,color:fg,size:17),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius:BorderRadius.circular(config.position=='floating'?config.radius:0),
      child: SizedBox(
        width:double.infinity,
        height:config.renderHeight,
        child:Stack(fit:StackFit.expand,children:[
          if(imageProvider!=null) Image(image:imageProvider,fit:BoxFit.cover,gaplessPlayback:true,errorBuilder:(_,__,___)=>ColoredBox(color:bg)),
          body,
        ]),
      ),
    );
  }
}

class _RotatingSearchHint extends StatefulWidget {
  const _RotatingSearchHint({required this.terms,required this.style});
  final List<String> terms;
  final TextStyle style;
  @override State<_RotatingSearchHint> createState()=>_RotatingSearchHintState();
}
class _RotatingSearchHintState extends State<_RotatingSearchHint> {
  Timer? _timer;
  int _index=0;
  @override void initState(){super.initState();_timer=Timer.periodic(const Duration(seconds:2),(_){if(mounted&&widget.terms.length>1)setState(()=>_index=(_index+1)%widget.terms.length);});}
  @override void didUpdateWidget(covariant _RotatingSearchHint oldWidget){super.didUpdateWidget(oldWidget);if(_index>=widget.terms.length)_index=0;}
  @override void dispose(){_timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){final term=widget.terms.isEmpty?'Search products...':widget.terms[_index%widget.terms.length];return AnimatedSwitcher(duration:const Duration(milliseconds:280),transitionBuilder:(child,animation)=>FadeTransition(opacity:animation,child:SlideTransition(position:Tween<Offset>(begin:const Offset(0,.25),end:Offset.zero).animate(animation),child:child)),child:Text(term,key:ValueKey(term),maxLines:1,overflow:TextOverflow.ellipsis,style:widget.style));}
}

class _AppBarIconPicker extends StatefulWidget {
  const _AppBarIconPicker();
  @override State<_AppBarIconPicker> createState()=>_AppBarIconPickerState();
}
class _AppBarIconPickerState extends State<_AppBarIconPicker>{
  String query='';String family='All';
  @override Widget build(BuildContext context){
    final icons=DesignerNavIcons.all.where((e)=>(family=='All'||e.family==family)&&(query.isEmpty||'${e.name} ${e.label}'.toLowerCase().contains(query.toLowerCase()))).toList();
    return AlertDialog(title:const Text('Choose Icon'),content:SizedBox(width:360,height:430,child:Column(children:[
      TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search all icons'),onChanged:(v)=>setState(()=>query=v)),
      const SizedBox(height:8),
      DropdownButtonFormField<String>(value:family,items:['All',...DesignerNavIcons.families].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>family=v??'All')),
      const SizedBox(height:8),
      Expanded(child:GridView.builder(itemCount:icons.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,crossAxisSpacing:5,mainAxisSpacing:5),itemBuilder:(_,i)=>InkWell(onTap:()=>Navigator.pop(context,icons[i]),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[DesignerNavIcons.icon(icons[i].family,icons[i].name,color:_appBarAccent,size:23),Text(icons[i].label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9))])))),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel'))]);
  }
}
