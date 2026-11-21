import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const storeUrl = 'https://pluginstore.shop';
const purple = Color(0xFF51408F);

class StoreApi {
  static String? nonce;
  static final Map<String,String> cookies={};
  static Uri uri(String path,[Map<String,String>? query])=>Uri.parse(storeUrl).resolve('wp-json/wc/store/v1/'+path).replace(queryParameters:query);
  static Map<String,String> get headers=>{'Accept':'application/json',if(cookies.isNotEmpty)'Cookie':cookies.entries.map((e)=>e.key+'='+e.value).join('; ')};
  static void capture(http.Response r){
    final n=r.headers['nonce']??r.headers['x-wc-store-api-nonce'];if(n!=null&&n.isNotEmpty)nonce=n;
    final c=r.headers['set-cookie'];if(c!=null){final first=c.split(';').first;final i=first.indexOf('=');if(i>0)cookies[first.substring(0,i).trim()]=first.substring(i+1).trim();}
  }
  static String message(String body){try{final d=jsonDecode(body);if(d is Map)return(d['message']??d['error']??body).toString();}catch(_){}return body.length>260?body.substring(0,260):body;}
  static Future<http.Response> getResponse(String path,[Map<String,String>? query])async{
    final r=await http.get(uri(path,query),headers:headers).timeout(const Duration(seconds:25));capture(r);
    if(r.statusCode<200||r.statusCode>=300)throw Exception('Store API '+r.statusCode.toString()+': '+message(r.body));return r;
  }
  static Future<dynamic> get(String path,[Map<String,String>? query])async=>jsonDecode((await getResponse(path,query)).body);
  static Future<dynamic> post(String path,Map<String,dynamic> body,String nonceValue)async{
    if(nonce==null||nonce!.isEmpty)await getResponse('cart');
    final h=<String,String>{...headers,'Content-Type':'application/json'};
    final n=nonceValue.isNotEmpty?nonceValue:nonce;if(n!=null&&n.isNotEmpty)h['Nonce']=n;
    final r=await http.post(uri(path),headers:h,body:jsonEncode(body)).timeout(const Duration(seconds:35));capture(r);
    if(r.statusCode<200||r.statusCode>=300)throw Exception('Store API '+r.statusCode.toString()+': '+message(r.body));return jsonDecode(r.body);
  }
  static Future<List<Map<String,dynamic>>> products({String search='',int? category,String order='date',int? exclude})async{
    final q=<String,String>{'page':'1','per_page':'40','orderby':order,'order':'desc','catalog_visibility':'visible'};
    if(search.trim().isNotEmpty)q['search']=search.trim();if(category!=null)q['category']=category.toString();if(exclude!=null)q['exclude']=exclude.toString();
    final v=await get('products',q);if(v is! List)throw Exception('Invalid products response');return v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  static Future<List<Map<String,dynamic>>> categories()async{final v=await get('products/categories',{'page':'1','per_page':'100','hide_empty':'true','orderby':'name'});if(v is! List)throw Exception('Invalid categories response');return v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}
  static Future<Map<String,dynamic>> cart()async=>Map<String,dynamic>.from(await get('cart') as Map);
  static Future<Map<String,dynamic>> add(int id,int qty,String n)async=>Map<String,dynamic>.from(await post('cart/add-item',{'id':id,'quantity':qty},n) as Map);
  static Future<Map<String,dynamic>> updateCustomer(Map<String,dynamic> address,String n)async=>Map<String,dynamic>.from(await post('cart/update-customer',{'billing_address':address,'shipping_address':address},n) as Map);
  static Future<Map<String,dynamic>> selectShipping(int packageId,String rateId,String n)async=>Map<String,dynamic>.from(await post('cart/select-shipping-rate',{'package_id':packageId,'rate_id':rateId},n) as Map);
}

void main()=>runApp(const GlowHitApp());

class GlowHitApp extends StatelessWidget {
  const GlowHitApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'GlowHit Shopping',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:purple),scaffoldBackgroundColor:const Color(0xFFF7F6FA)),
    home:const StoreHome(),
  );
}

class StoreHome extends StatefulWidget {
  const StoreHome({super.key});
  @override State<StoreHome> createState()=>_StoreHomeState();
}
class _StoreHomeState extends State<StoreHome> {
  int tab=0; bool loading=false; String? error; String search='';
  int? categoryId; String categoryName='Shopping';
  final searchController=TextEditingController();
  List<Map<String,dynamic>> products=[];
  List<Map<String,dynamic>> categories=[];
  List<Map<String,dynamic>> wishlist=[];
  final Map<int,Map<String,dynamic>> cartItems={};

  @override void initState(){super.initState();loadProducts();loadCategories();}
  @override void dispose(){searchController.dispose();super.dispose();}
  Future<void> loadProducts({String order='date'}) async {
    setState(()=>loading=true); 
    try {final p=await StoreApi.products(search:search,category:categoryId,order:order);if(mounted)setState(()=>products=p);}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> loadCategories() async {
    try{final c=await StoreApi.categories();if(mounted)setState(()=>categories=c);}
    catch(e){if(mounted&&categories.isEmpty)setState(()=>error=e.toString());}
  }
  int get cartCount=>cartItems.values.fold(0,(n,p)=>n+((p['_qty'] as int?)??1));
  String price(Map p){
    final v=p['prices'];
    if(v is Map){final raw=int.tryParse((v['price']??'').toString())??0;final d=(v['currency_minor_unit'] as num?)?.toInt()??2;final div=d==0?1:(d==1?10:100);return (v['currency_symbol']??'₹').toString()+(raw/div).toStringAsFixed(d);}
    return (p['price']??'').toString();
  }
  String image(Map p,[int index=0]){
    final a=p['images'];if(a is List&&a.length>index&&a[index] is Map)return ((a[index] as Map)['thumbnail']??(a[index] as Map)['src']??'').toString();return '';
  }
  void add(Map<String,dynamic> p){
    final id=(p['id'] as num?)?.toInt()??0;if(id==0)return;
    setState(()=>cartItems[id]={...p,'_qty':((cartItems[id]?['_qty'] as int?)??0)+1});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Added to cart'),duration:Duration(seconds:1)));
  }
  Widget card(Map<String,dynamic> p){
    final id=(p['id'] as num?)?.toInt()??0;final liked=wishlist.any((e)=>e['id']==id);
    return Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProductPage(product:p,price:price,image:image,onAdd:()=>add(p),onBuyNow:(){add(p);Navigator.pop(context);setState(()=>tab=3);}))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Stack(fit:StackFit.expand,children:[
          Container(color:Colors.white,child:image(p).isEmpty?const Icon(Icons.image_outlined,size:42):Image.network(image(p),fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image))),
          Positioned(right:2,top:2,child:IconButton.filledTonal(onPressed:()=>setState(()=>liked?wishlist.removeWhere((e)=>e['id']==id):wishlist.add(p)),icon:Icon(liked?Icons.favorite:Icons.favorite_border,color:liked?Colors.red:null))),
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(8,6,8,2),child:Text((p['name']??'Product').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Text(price(p),style:const TextStyle(color:purple,fontWeight:FontWeight.bold))),
        Padding(padding:const EdgeInsets.all(6),child:SizedBox(width:double.infinity,child:FilledButton.tonal(onPressed:()=>add(p),child:const Text('ADD TO CART')))),
      ])));
  }
  Widget home()=>Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:TextField(controller:searchController,onSubmitted:(v){search=v;loadProducts();},decoration:InputDecoration(hintText:'Search products',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:(){searchController.clear();search='';loadProducts();},icon:const Icon(Icons.close)),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)))),
    Container(margin:const EdgeInsets.symmetric(horizontal:12),padding:const EdgeInsets.all(18),width:double.infinity,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF33205F),Color(0xFF92517F)]),borderRadius:BorderRadius.circular(18)),child:const Text('Find your next favourite thing.\nSHOP THE COLLECTION →',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold))),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      for(final x in [('For You','date'),('Top Rated','rating'),('Popular','popularity')]) Padding(padding:const EdgeInsets.all(6),child:OutlinedButton(onPressed:()=>loadProducts(order:x.$2),child:Text(x.$1))),
    ])),
    if(loading)const Expanded(child:Center(child:CircularProgressIndicator()))
    else if(error!=null&&products.isEmpty)Expanded(child:Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.red)),FilledButton(onPressed:loadProducts,child:const Text('Retry'))]))))
    else if(products.isEmpty)const Expanded(child:Center(child:Text('No products found')))
    else Expanded(child:GridView.builder(padding:const EdgeInsets.all(10),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.66,crossAxisSpacing:10,mainAxisSpacing:10),itemCount:products.length,itemBuilder:(_,i)=>card(products[i]))),
  ]);
  Widget categoryPage()=>categories.isEmpty?Center(child:FilledButton(onPressed:loadCategories,child:const Text('Load categories'))):ListView(children:[
    ListTile(leading:const Icon(Icons.grid_view),title:const Text('All products'),onTap:(){setState((){categoryId=null;categoryName='Shopping';tab=0;});loadProducts();}),
    for(final c in categories)ListTile(
      leading:CircleAvatar(backgroundColor:Colors.white,child:Text((c['name']??'C').toString().substring(0,1))),
      title:Text((c['name']??'Category').toString()),trailing:Text((c['count']??'').toString()),
      onTap:(){setState((){categoryId=(c['id'] as num?)?.toInt();categoryName=(c['name']??'Category').toString();tab=0;});loadProducts();},
    )
  ]);
  Widget cartPage()=>cartItems.isEmpty?const Center(child:Text('Your cart is empty')):ListView(padding:const EdgeInsets.all(12),children:[
    for(final e in cartItems.entries)Card(child:ListTile(
      leading:SizedBox(width:55,child:image(e.value).isEmpty?const Icon(Icons.image):Image.network(image(e.value),fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported))),
      title:Text((e.value['name']??'Product').toString(),maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text(price(e.value)),
      trailing:Row(mainAxisSize:MainAxisSize.min,children:[
        IconButton(onPressed:()=>setState(()=>((e.value['_qty'] as int)<=1)?cartItems.remove(e.key):cartItems[e.key]!['_qty']=(e.value['_qty'] as int)-1),icon:const Icon(Icons.remove)),
        Text((e.value['_qty']??1).toString()),
        IconButton(onPressed:()=>setState(()=>cartItems[e.key]!['_qty']=(e.value['_qty'] as int)+1),icon:const Icon(Icons.add)),
      ]),
    )),
    FilledButton(onPressed:()async{final done=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>CheckoutPage(items:cartItems.values.toList())));if(done==true&&mounted)setState(()=>cartItems.clear());},child:const Text('PROCEED TO CHECKOUT')),
  ]);
  @override Widget build(BuildContext context){
    final titles=['Shopping','Categories','Wishlist','Cart','Account'];
    final Widget page=tab==0?home():tab==1?categoryPage():tab==2?(wishlist.isEmpty?const Center(child:Text('Your wishlist is empty')):GridView.count(crossAxisCount:2,childAspectRatio:.66,children:wishlist.map(card).toList())):tab==3?cartPage():const AccountPage();
    return Scaffold(appBar:AppBar(title:Text(tab==0&&categoryId!=null?categoryName:titles[tab]),actions:[if(tab==0)IconButton(onPressed:loadProducts,icon:const Icon(Icons.refresh))]),body:SafeArea(child:page),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:[
        const NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        const NavigationDestination(icon:Icon(Icons.grid_view),label:'Categories'),
        const NavigationDestination(icon:Icon(Icons.favorite_border),label:'Wishlist'),
        NavigationDestination(icon:Badge(label:Text(cartCount.toString()),child:const Icon(Icons.shopping_bag_outlined)),label:'Cart'),
        const NavigationDestination(icon:Icon(Icons.person_outline),label:'Account'),
      ]));
  }
}

class ProductPage extends StatefulWidget{
  const ProductPage({super.key,required this.product,required this.price,required this.image,required this.onAdd,required this.onBuyNow});
  final Map<String,dynamic> product;final String Function(Map) price;final String Function(Map,[int]) image;final VoidCallback onAdd,onBuyNow;
  @override State<ProductPage> createState()=>_ProductPageState();
}
class _ProductPageState extends State<ProductPage>{
  final PageController page=PageController();Timer? timer;int index=0;bool expanded=false,similarLoading=true;List<Map<String,dynamic>> similar=[];
  List<dynamic> get pics=>widget.product['images'] is List?widget.product['images'] as List:[];
  String get description{
    var t=(widget.product['description']??widget.product['short_description']??'').toString();
    t=t.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>',caseSensitive:false),' ');
    t=t.replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>',caseSensitive:false),' ').replaceAll(RegExp(r'<[^>]+>'),' ');
    for(final e in {'&nbsp;':' ','&amp;':'&','&quot;':'"','&#39;':"'",'&lt;':'<','&gt;':'>'}.entries){t=t.replaceAll(e.key,e.value);}
    return t.replaceAll(RegExp(r'\s+'),' ').trim();
  }
  List<String> get descriptionImages{
    final h=(widget.product['description']??'').toString();
    return RegExp(r'<img[^>]+(?:src|data-src)=["\x27]([^"\x27]+)',caseSensitive:false).allMatches(h).map((m)=>m.group(1)??'').where((v)=>v.startsWith('http')).toSet().toList();
  }
  String get category{final c=widget.product['categories'];return c is List&&c.isNotEmpty&&c.first is Map?(c.first['name']??'—').toString():'—';}
  String get vendor{final b=widget.product['brands'];if(b is List&&b.isNotEmpty&&b.first is Map)return(b.first['name']??'').toString();final x=widget.product['extensions'];return x is Map&&x['vendor']!=null?x['vendor'].toString():'Not provided by store';}
  @override void initState(){super.initState();if(pics.length>1)timer=Timer.periodic(const Duration(seconds:4),(_){if(mounted&&page.hasClients)page.animateToPage((index+1)%pics.length,duration:const Duration(milliseconds:450),curve:Curves.easeInOut);});loadSimilar();}
  Future<void> loadSimilar()async{try{final c=widget.product['categories'];if(c is List&&c.isNotEmpty&&c.first is Map){final id=(c.first['id'] as num?)?.toInt();if(id!=null){final p=await StoreApi.products(category:id,exclude:(widget.product['id'] as num?)?.toInt());if(mounted)setState(()=>similar=p.take(8).toList());}}}catch(_){}if(mounted)setState(()=>similarLoading=false);}
  @override void dispose(){timer?.cancel();page.dispose();super.dispose();}
  void openFull(int i)=>showDialog<void>(context:context,barrierColor:Colors.black,builder:(_)=>_FullImageDialog(images:pics,index:i));
  Widget gallery()=>Column(children:[
    SizedBox(height:350,child:pics.isEmpty?const Center(child:Icon(Icons.image_outlined,size:80,color:Colors.grey)):PageView.builder(controller:page,itemCount:pics.length,onPageChanged:(i)=>setState(()=>index=i),itemBuilder:(c,i){final src=(pics[i] is Map?(pics[i]['src']??pics[i]['thumbnail']??''):'').toString();return GestureDetector(onTap:()=>openFull(i),child:Container(color:Colors.white,padding:const EdgeInsets.all(10),child:Image.network(src,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,size:60))));})),
    if(pics.length>1)Padding(padding:const EdgeInsets.only(top:8),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[for(int i=0;i<pics.length;i++)GestureDetector(onTap:()=>page.animateToPage(i,duration:const Duration(milliseconds:250),curve:Curves.ease),child:Container(width:8,height:8,margin:const EdgeInsets.symmetric(horizontal:4),decoration:BoxDecoration(shape:BoxShape.circle,color:i==index?purple:Colors.grey.shade400)))])),
    if(pics.length>1)SizedBox(height:78,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(vertical:8),itemCount:pics.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(c,i){final src=(pics[i] is Map?(pics[i]['thumbnail']??pics[i]['src']??''):'').toString();return GestureDetector(onTap:()=>page.animateToPage(i,duration:const Duration(milliseconds:250),curve:Curves.ease),child:Container(width:68,padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:Colors.white,border:Border.all(color:i==index?purple:Colors.black12,width:i==index?2:1),borderRadius:BorderRadius.circular(8)),child:Image.network(src,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.image))));}))
  ]);
  Widget info(IconData icon,String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[Icon(icon,size:19,color:purple),const SizedBox(width:10),SizedBox(width:88,child:Text(label,style:const TextStyle(color:Colors.black54))),Expanded(child:Text(value.isEmpty?'—':value,style:const TextStyle(fontWeight:FontWeight.w600)))]));
  Widget descriptionBlock()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Product description',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:8),
    Text(description.isEmpty?'No description provided by store.':(!expanded&&description.length>100?description.substring(0,100)+'…':description)),
    if(description.length>100)Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()=>setState(()=>expanded=!expanded),icon:Icon(expanded?Icons.expand_less:Icons.expand_more),label:Text(expanded?'Read Less':'More Read'))),
    for(final src in descriptionImages)Padding(padding:const EdgeInsets.only(top:10),child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(src,width:double.infinity,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const SizedBox.shrink())))
  ]);
  Widget similarBlock(){
    if(similarLoading)return const Padding(padding:EdgeInsets.all(18),child:Center(child:CircularProgressIndicator()));if(similar.isEmpty)return const SizedBox.shrink();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Similar products',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:10),
      SizedBox(height:210,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:similar.length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(c,i){
        final p=similar[i],imgs=p['images'];final src=imgs is List&&imgs.isNotEmpty&&imgs.first is Map?(imgs.first['thumbnail']??imgs.first['src']??'').toString():'';
        final pr=p['prices'];var priceText='';if(pr is Map){final raw=int.tryParse((pr['price']??'').toString())??0;final d=(pr['currency_minor_unit'] as num?)?.toInt()??2;priceText=(pr['currency_symbol']??'₹').toString()+(raw/(d==0?1:(d==1?10:100))).toStringAsFixed(d);}
        return SizedBox(width:145,child:Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ProductPage(product:p,price:widget.price,image:widget.image,onAdd:widget.onAdd,onBuyNow:widget.onBuyNow))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:Container(color:Colors.white,child:src.isEmpty?const Icon(Icons.image):Image.network(src,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported)))),
          Padding(padding:const EdgeInsets.all(7),child:Text((p['name']??'Product').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12))),
          Padding(padding:const EdgeInsets.fromLTRB(7,0,7,7),child:Text(priceText,style:const TextStyle(color:purple,fontWeight:FontWeight.bold)))
        ]))));
      }))
    ]);
  }
  @override Widget build(BuildContext context){
    final canBuy=widget.product['is_purchasable']!=false&&widget.product['is_in_stock']!=false;final sku=(widget.product['sku']??'').toString();
    return Scaffold(appBar:AppBar(title:const Text('Product details'),actions:[IconButton(onPressed:()=>openFull(index),icon:const Icon(Icons.fullscreen))]),
      body:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,110),children:[
        gallery(),const SizedBox(height:18),Text((widget.product['name']??'Product').toString(),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w700)),
        const SizedBox(height:10),Text(widget.price(widget.product),style:const TextStyle(fontSize:28,color:purple,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),Row(children:[Icon(canBuy?Icons.check_circle:Icons.cancel,color:canBuy?Colors.green:Colors.red,size:18),const SizedBox(width:7),Text(canBuy?'In stock':'Currently unavailable')]),
        const Divider(height:28),info(Icons.qr_code,'SKU',sku.isEmpty?'Not available':sku),info(Icons.category_outlined,'Category',category),info(Icons.storefront_outlined,'Vendor',vendor),
        const Divider(height:28),descriptionBlock(),const Divider(height:30),similarBlock()
      ]),
      bottomNavigationBar:SafeArea(top:false,child:Container(padding:const EdgeInsets.fromLTRB(12,10,12,10),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,boxShadow:[BoxShadow(color:Colors.black.withOpacity(.10),blurRadius:12,offset:const Offset(0,-3))]),child:Row(children:[
        SizedBox(width:58,height:52,child:OutlinedButton(onPressed:canBuy?widget.onAdd:null,style:OutlinedButton.styleFrom(padding:EdgeInsets.zero),child:const Icon(Icons.shopping_cart_outlined))),const SizedBox(width:10),
        Expanded(child:SizedBox(height:52,child:FilledButton(onPressed:canBuy?widget.onBuyNow:null,style:FilledButton.styleFrom(backgroundColor:purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),child:const Text('BUY NOW',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:.5)))))
      ])))
    );
  }
}
class _FullImageDialog extends StatefulWidget{
  const _FullImageDialog({required this.images,required this.index});final List<dynamic> images;final int index;
  @override State<_FullImageDialog> createState()=>_FullImageDialogState();
}
class _FullImageDialogState extends State<_FullImageDialog>{
  late final PageController controller=PageController(initialPage:widget.index);
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Dialog.fullscreen(backgroundColor:Colors.black,child:Stack(children:[
    PageView.builder(controller:controller,itemCount:widget.images.length,itemBuilder:(c,i){final src=(widget.images[i] is Map?(widget.images[i]['src']??widget.images[i]['thumbnail']??''):'').toString();return Center(child:InteractiveViewer(minScale:1,maxScale:5,child:Image.network(src,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,color:Colors.white,size:60))));}),
    Positioned(top:24,right:12,child:IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close,color:Colors.white,size:30)))
  ]));
}
class CheckoutPage extends StatefulWidget{
  const CheckoutPage({super.key,required this.items});final List<Map<String,dynamic>> items;
  @override State<CheckoutPage> createState()=>_CheckoutPageState();
}
class _CheckoutPageState extends State<CheckoutPage>{
  final keyForm=GlobalKey<FormState>();
  final first=TextEditingController(),last=TextEditingController(),email=TextEditingController(),phone=TextEditingController(),address=TextEditingController(),city=TextEditingController(),state=TextEditingController(),pin=TextEditingController();
  String payment='cod';String? nonce,error,shippingRateId;bool busy=false,ready=false;
  Map<String,dynamic>? cartData;List<Map<String,dynamic>> paymentMethods=[],shippingRates=[];
  @override void initState(){super.initState();prepare();}
  @override void dispose(){for(final c in [first,last,email,phone,address,city,state,pin]){c.dispose();}super.dispose();}
  Map<String,dynamic> get addressData=>{'first_name':first.text.trim(),'last_name':last.text.trim(),'email':email.text.trim(),'phone':phone.text.trim(),'address_1':address.text.trim(),'city':city.text.trim(),'state':state.text.trim(),'postcode':pin.text.trim(),'country':'IN'};
  List<Map<String,dynamic>> extractRates(Map<String,dynamic> cart){
    final out=<Map<String,dynamic>>[];final packs=cart['shipping_rates'];
    if(packs is List)for(int i=0;i<packs.length;i++){final p=packs[i];if(p is Map){final rates=p['shipping_rates']??p['rates'];if(rates is List)for(final r in rates)if(r is Map)out.add({...Map<String,dynamic>.from(r),'_package_id':p['package_id']??i});}}
    return out;
  }
  Future<void> prepare()async{
    try{
      var c=await StoreApi.cart();nonce=StoreApi.nonce??'';
      for(final p in widget.items){final id=(p['id'] as num?)?.toInt()??0;if(id>0){c=await StoreApi.add(id,(p['_qty'] as int?)??1,nonce??'');nonce=StoreApi.nonce??nonce;}}
      c=await StoreApi.cart();nonce=StoreApi.nonce??nonce;
      List<Map<String,dynamic>> methods=[];
      try{final x=await StoreApi.get('checkout');if(x is Map&&x['payment_methods'] is List)methods=(x['payment_methods'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();}catch(_){}
      if(mounted)setState((){
        cartData=c;paymentMethods=methods;shippingRates=extractRates(c);
        if(methods.isNotEmpty)payment=methods.any((m)=>m['id']=='cod')?'cod':(methods.first['id']??'').toString();
        if(shippingRates.isNotEmpty)shippingRateId=(shippingRates.first['rate_id']??shippingRates.first['id']??'').toString();
        ready=true;
      });
    }catch(e){if(mounted)setState(()=>error='Could not prepare WooCommerce cart: '+e.toString());}
  }
  Widget field(TextEditingController c,String label,{TextInputType type=TextInputType.text})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextFormField(controller:c,keyboardType:type,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),validator:(v)=>v==null||v.trim().isEmpty?'Enter '+label:null));
  Future<void> calculateShipping()async{
    if(!keyForm.currentState!.validate())return;
    setState(()=>busy=true);
    try{
      await StoreApi.updateCustomer(addressData,nonce??'');nonce=StoreApi.nonce??nonce;
      final cart=await StoreApi.cart();nonce=StoreApi.nonce??nonce;
      if(mounted)setState((){cartData=cart;shippingRates=extractRates(cart);shippingRateId=shippingRates.isNotEmpty?(shippingRates.first['rate_id']??shippingRates.first['id']??'').toString():null;error=null;});
    }catch(e){if(mounted)setState(()=>error='Shipping calculation failed: '+e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> chooseShipping(Map<String,dynamic> rate)async{
    final package=(rate['_package_id'] as num?)?.toInt()??0;final id=(rate['rate_id']??rate['id']??'').toString();if(id.isEmpty)return;
    setState(()=>busy=true);
    try{final c=await StoreApi.selectShipping(package,id,nonce??'');nonce=StoreApi.nonce??nonce;if(mounted)setState(()=>cartData=c);}
    catch(e){if(mounted)setState(()=>error='Shipping selection failed: '+e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  String get totalLabel{
    final t=cartData?['totals'];if(t is Map){final raw=int.tryParse((t['total_price']??'').toString())??0;final d=(t['currency_minor_unit'] as num?)?.toInt()??2;final sym=(t['currency_symbol']??'₹').toString();return sym+(raw/(d==0?1:(d==1?10:100))).toStringAsFixed(d);}return '';
  }
  Future<void> submit()async{
    if(!keyForm.currentState!.validate())return;if(!ready){setState(()=>error='Cart is still preparing.');return;}
    setState((){busy=true;error=null;});
    try{
      final r=await StoreApi.post('checkout',{'billing_address':addressData,'shipping_address':addressData,'payment_method':payment,'payment_data':<Map<String,dynamic>>[]},nonce??'');
      nonce=StoreApi.nonce??nonce;
      final redirect=(r['payment_result'] is Map?(r['payment_result']['redirect_url']??''):'').toString();
      final id=r['order_id']??r['id']??'';
      if(!mounted)return;
      if(redirect.isNotEmpty){setState(()=>error='Payment gateway returned this secure payment link: '+redirect);}
      else{
        await showDialog<void>(context:context,builder:(_)=>AlertDialog(title:const Text('Order submitted'),content:Text('Order reference: '+id.toString()+'\nStatus: '+(r['status']??'received').toString()),actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Done'))]));
        if(mounted)Navigator.pop(context,true);
      }
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Checkout')),body:Form(key:keyForm,child:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Delivery address',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:12),
    Row(children:[Expanded(child:field(first,'First name')),const SizedBox(width:8),Expanded(child:field(last,'Last name'))]),
    field(email,'Email',type:TextInputType.emailAddress),field(phone,'Phone',type:TextInputType.phone),field(address,'Address'),
    Row(children:[Expanded(child:field(city,'City')),const SizedBox(width:8),Expanded(child:field(state,'State'))]),field(pin,'PIN code',type:TextInputType.number),
    OutlinedButton.icon(onPressed:busy?null:calculateShipping,icon:const Icon(Icons.local_shipping_outlined),label:const Text('CALCULATE SHIPPING')),
    const Divider(height:28),const Text('Shipping',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
    if(shippingRates.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:10),child:Text('Enter your address and calculate the shipping options available for your PIN code.'))
    else ...shippingRates.map((r){final id=(r['rate_id']??r['id']??'').toString();final name=(r['name']??r['method_title']??'Shipping').toString();final cost=(r['price']??r['cost']??'').toString();return RadioListTile<String>(value:id,groupValue:shippingRateId,title:Text(name),subtitle:cost.isEmpty?null:Text(cost),onChanged:(v){setState(()=>shippingRateId=v);chooseShipping(r);});}),
    const Divider(height:28),const Text('Payment',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
    if(paymentMethods.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:10),child:Text('WooCommerce did not return any active payment methods. Enable Cash on Delivery or an online gateway in WooCommerce settings.'))
    else ...paymentMethods.map((m){final id=(m['id']??'').toString();final name=(m['title']??m['method_title']??id).toString();return RadioListTile<String>(value:id,groupValue:payment,title:Text(name),onChanged:(v)=>setState(()=>payment=v??id));}),
    if(totalLabel.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text('Order total: '+totalLabel,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))),
    if(error!=null)Padding(padding:const EdgeInsets.only(bottom:10),child:SelectableText(error!,style:const TextStyle(color:Colors.red))),
    FilledButton(onPressed:busy||!ready||paymentMethods.isEmpty?null:submit,child:Text(!ready?'Preparing cart...':busy?'Please wait...':'PLACE ORDER'))
  ])));
}
class AccountPage extends StatelessWidget{
  const AccountPage({super.key});
  @override Widget build(BuildContext context)=>const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Customer account and order history will be added after this shopping checkout stage is verified.',textAlign:TextAlign.center)));
}
