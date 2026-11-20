import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const storeUrl = 'https://pluginstore.shop';
const purple = Color(0xFF51408F);

class StoreApi {
  static Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse(storeUrl).resolve('wp-json/wc/store/v1/' + path).replace(queryParameters: query);
  static Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final r = await http.get(uri(path, query), headers: const {'Accept':'application/json'}).timeout(const Duration(seconds: 25));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Store API ' + r.statusCode.toString() + ': ' + message(r.body));
    return jsonDecode(r.body);
  }
  static Future<dynamic> post(String path, Map<String, dynamic> body, String nonce) async {
    final r = await http.post(uri(path), headers: {'Accept':'application/json','Content-Type':'application/json','Nonce':nonce}, body:jsonEncode(body)).timeout(const Duration(seconds:30));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Store API ' + r.statusCode.toString() + ': ' + message(r.body));
    return jsonDecode(r.body);
  }
  static String message(String body) {
    try { final d=jsonDecode(body); if (d is Map) return (d['message'] ?? d['error'] ?? body).toString(); } catch (_) {}
    return body.length > 240 ? body.substring(0,240) : body;
  }
  static Future<List<Map<String,dynamic>>> products({String search='', int? category, String order='date'}) async {
    final q=<String,String>{'page':'1','per_page':'40','orderby':order,'order':'desc','catalog_visibility':'visible'};
    if(search.trim().isNotEmpty) q['search']=search.trim();
    if(category!=null) q['category']=category.toString();
    final v=await get('products',q);
    if(v is! List) throw Exception('Invalid products response');
    return v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  static Future<List<Map<String,dynamic>>> categories() async {
    final v=await get('products/categories',{'page':'1','per_page':'100','hide_empty':'true','orderby':'name'});
    if(v is! List) throw Exception('Invalid categories response');
    return v.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  static Future<Map<String,dynamic>> cart() async => Map<String,dynamic>.from(await get('cart') as Map);
  static Future<Map<String,dynamic>> add(int id,int qty,String nonce) async =>
      Map<String,dynamic>.from(await post('cart/add-item',{'id':id,'quantity':qty},nonce) as Map);
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
    return Card(clipBehavior:Clip.antiAlias,child:InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProductPage(product:p,price:price,image:image,onAdd:()=>add(p)))),
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

class ProductPage extends StatelessWidget{
  const ProductPage({super.key,required this.product,required this.price,required this.image,required this.onAdd});
  final Map<String,dynamic> product;final String Function(Map) price;final String Function(Map,[int]) image;final VoidCallback onAdd;
  @override Widget build(BuildContext context){
    final pics=product['images'] is List?product['images'] as List:const [];
    final desc=(product['description']??product['short_description']??'').toString().replaceAll(RegExp(r'<[^>]*>'),' ').replaceAll('&nbsp;',' ').trim();
    return Scaffold(appBar:AppBar(title:const Text('Product details')),body:ListView(padding:const EdgeInsets.all(16),children:[
      SizedBox(height:300,child:pics.isEmpty?const Icon(Icons.image,size:80):PageView(children:[for(final p in pics)Image.network((p is Map?(p['src']??p['thumbnail']??''):'').toString(),fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image,size:60))])),
      const SizedBox(height:16),Text((product['name']??'Product').toString(),style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),Text(price(product),style:const TextStyle(fontSize:24,color:purple,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),Text(product['is_in_stock']==true?'In stock':'Availability may vary'),
      const Divider(height:28),const Text('Product description',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      Text(desc.isEmpty?'Product details are supplied by the store.':desc),
      const SizedBox(height:20),FilledButton.icon(onPressed:product['is_purchasable']==false?null:onAdd,icon:const Icon(Icons.shopping_cart),label:const Text('ADD TO CART')),
    ]));
  }
}

class CheckoutPage extends StatefulWidget{
  const CheckoutPage({super.key,required this.items});final List<Map<String,dynamic>> items;
  @override State<CheckoutPage> createState()=>_CheckoutPageState();
}
class _CheckoutPageState extends State<CheckoutPage>{
  final keyForm=GlobalKey<FormState>();
  final first=TextEditingController(),last=TextEditingController(),email=TextEditingController(),phone=TextEditingController(),address=TextEditingController(),city=TextEditingController(),state=TextEditingController(),pin=TextEditingController();
  String payment='cod';String? nonce,error;bool busy=false,ready=false;
  @override void initState(){super.initState();prepare();}
  @override void dispose(){for(final c in [first,last,email,phone,address,city,state,pin]){c.dispose();}super.dispose();}
  Future<void> prepare()async{
    try{var c=await StoreApi.cart();nonce=(c['nonce']??'').toString();for(final p in widget.items){final id=(p['id'] as num?)?.toInt()??0;if(id>0){c=await StoreApi.add(id,(p['_qty'] as int?)??1,nonce??'');nonce=(c['nonce']??nonce??'').toString();}}if(mounted)setState(()=>ready=true);}
    catch(e){if(mounted)setState(()=>error='Could not sync cart with store: '+e.toString());}
  }
  Widget field(TextEditingController c,String label,{TextInputType type=TextInputType.text})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextFormField(controller:c,keyboardType:type,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),validator:(v)=>v==null||v.trim().isEmpty?'Enter '+label:null));
  Future<void> submit()async{
    if(!keyForm.currentState!.validate())return;if(nonce==null||nonce!.isEmpty){setState(()=>error='Store cart is not ready. Retry.');return;}
    setState(()=>{busy=true,error=null;});
    try{
      final billing={'first_name':first.text.trim(),'last_name':last.text.trim(),'email':email.text.trim(),'phone':phone.text.trim(),'address_1':address.text.trim(),'city':city.text.trim(),'state':state.text.trim(),'postcode':pin.text.trim(),'country':'IN'};
      final body={'billing_address':billing,'shipping_address':billing,'payment_method':payment,'payment_data':<Map<String,dynamic>>[]};
      final r=await StoreApi.post('checkout',body,nonce!);
      final id=r['order_id']??r['id']??'';
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(_)=>AlertDialog(title:const Text('Order response received'),content:Text('Order reference: '+id.toString()+'\n'+(r['payment_result']??r).toString().substring(0,((r['payment_result']??r).toString().length).clamp(0,240))),actions:[FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Done'))]));
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Checkout')),body:Form(key:keyForm,child:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Delivery address',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:12),
    Row(children:[Expanded(child:field(first,'First name')),const SizedBox(width:8),Expanded(child:field(last,'Last name'))]),
    field(email,'Email',type:TextInputType.emailAddress),field(phone,'Phone',type:TextInputType.phone),field(address,'Address'),
    Row(children:[Expanded(child:field(city,'City')),const SizedBox(width:8),Expanded(child:field(state,'State'))]),field(pin,'PIN code',type:TextInputType.number),
    const Divider(height:28),const Text('Shipping',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
    const Text('Shipping options and charges are calculated by WooCommerce during checkout.'),
    const Divider(height:28),const Text('Payment',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
    RadioListTile<String>(value:'cod',groupValue:payment,onChanged:(v)=>setState(()=>payment=v!),title:const Text('Cash on Delivery')),
    RadioListTile<String>(value:'online',groupValue:payment,onChanged:(v)=>setState(()=>payment=v!),title:const Text('Online payment (requires a compatible store gateway)')),
    if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
    FilledButton(onPressed:busy||!ready?null:submit,child:Text(!ready?'Preparing cart...':busy?'Please wait...':'PLACE ORDER')),
  ])));
}

class AccountPage extends StatelessWidget{
  const AccountPage({super.key});
  @override Widget build(BuildContext context)=>const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Customer account and order history will be added after this shopping checkout stage is verified.',textAlign:TextAlign.center)));
}
