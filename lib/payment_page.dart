import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'customer_account_page.dart';
import 'woo_store_api.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.api, required this.address, required this.cart, this.customerToken});
  final WooStoreApi api;
  final String? customerToken;
  final Map<String, dynamic> address;
  final Map<String, dynamic> cart;
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const _brand = Color(0xFF51408F);
  final _utrController = TextEditingController();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> methods = [];
  Map<String, dynamic> upi = {};
  Map<String, dynamic> liveCart = {};
  String? selected;
  bool loading = true, paying = false, submittingUpi = false;
  String? error;
  Map<String, dynamic>? createdOrder;
  Uint8List? screenshotBytes;
  String screenshotName = 'upi-payment.jpg';

  @override
  void initState() { super.initState(); liveCart = Map<String, dynamic>.from(widget.cart); loadMethods(); }

  @override
  void dispose() { _utrController.dispose(); super.dispose(); }

  Future<void> loadMethods() async {
    try {
      // Refresh the authoritative cart totals before showing the amount.
      // A stale/empty checkout snapshot must never be treated as ₹0.00.
      try {
        final refreshed = await widget.api.getCart();
        if (refreshed['totals'] is Map) liveCart = refreshed;
      } catch (_) {
        // Continue loading gateway configuration; the order action is guarded below.
      }
      Map<String, dynamic> checkout = {};
      try { checkout = await widget.api.getCheckout(); } catch (e) {
        error = 'Checkout details could not be loaded. ${e.toString().replaceFirst('Exception: ', '')}';
      }
      // The bridge adds UPI-specific settings. Its temporary failure must not
      // hide a working WooCommerce COD method returned by Store API.
      Map<String, dynamic> config = {};
      try {
        config = await widget.api.getNativePaymentConfig();
      } catch (_) {
        config = {};
      }
      final raw = (checkout['payment_methods'] as List? ?? const []);
      final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final gatewayList = (config['gateways'] as List? ?? const [])
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final byId = <String, Map<String, dynamic>>{};
      for (final method in list) {
        final id = (method['id'] ?? '').toString();
        if (id.isNotEmpty) byId[id] = method;
      }
      for (final method in gatewayList) {
        final id = (method['id'] ?? '').toString();
        if (id.isNotEmpty) byId.putIfAbsent(id, () => method);
      }
      final upiConfig = config['upi'] is Map
          ? Map<String, dynamic>.from(config['upi'] as Map)
          : <String, dynamic>{};
      if (upiConfig['available'] == true) {
        byId.putIfAbsent('wc-upi', () => {
          'id': 'wc-upi',
          'title': upiConfig['title'] ?? 'UPI QR Payment',
          'description': upiConfig['description'] ?? 'Pay using any UPI app',
        });
      }
      final available = byId.values.toList();
      if (mounted) setState(() {
        methods = available;
        upi = upiConfig;
        selected = available.isEmpty ? null : available.first['id']?.toString();
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  Map? get totals => createdOrder?['totals'] is Map
      ? createdOrder!['totals'] as Map
      : (liveCart['totals'] is Map ? liveCart['totals'] as Map : null);
  int get totalMinor => int.tryParse('${totals?['total_price'] ?? '0'}') ?? 0;
  int get minorUnit => (totals?['currency_minor_unit'] as num?)?.toInt() ?? 2;
  double get amountValue => totalMinor / (minorUnit == 0 ? 1 : (minorUnit == 1 ? 10 : 100));

  String money(Map? data) {
    if (data == null) return '₹0.00';
    final raw = int.tryParse('${data['total_price'] ?? data['line_total'] ?? data['price'] ?? '0'}') ?? 0;
    final digits = (data['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
    return '${data['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
  }

  String get upiUri {
    final vpa = (upi['merchant_vpa'] ?? '').toString();
    final name = (upi['merchant_name'] ?? 'GlowHit Store').toString();
    final orderId = createdOrder?['order_id'] ?? createdOrder?['id'] ?? '';
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': vpa,
        'pn': name,
        'am': amountValue.toStringAsFixed(2),
        'cu': 'INR',
        'tn': 'GlowHit Order $orderId',
      },
    ).toString();
  }

  Future<void> placeOrder() async {
    if (selected == null) {
      setState(() => error = 'No active payment method is available. Check WooCommerce → Settings → Payments and the ARK Native API Bridge.');
      return;
    }
    if (totalMinor <= 0) {
      setState(() => error = 'Order total is unavailable. Refresh your cart and confirm the payable amount before placing the order.');
      return;
    }
    setState(() { paying = true; error = null; });
    try {
      if (selected == 'wc-upi' && (upi['merchant_vpa'] ?? '').toString().trim().isEmpty) {
        throw Exception('The store has not configured its merchant UPI address. Please contact the store.');
      }

      // Reconcile the exact address selected in checkout with the live
      // WooCommerce cart before creating the order. This prevents a stale
      // default address from replacing a customer's alternate address.
      const wooAddressFields = [
        'first_name', 'last_name', 'company', 'address_1', 'address_2',
        'city', 'state', 'postcode', 'country', 'email', 'phone',
      ];
      final selectedAddress = <String, dynamic>{
        for (final key in wooAddressFields)
          if (widget.address.containsKey(key)) key: widget.address[key],
      };
      final currentCart = await widget.api.getCart();
      Map<String, dynamic> serverShipping = currentCart['shipping_address'] is Map
          ? Map<String, dynamic>.from(currentCart['shipping_address'] as Map)
          : <String, dynamic>{};
      String fieldValue(Map<String, dynamic> value, String key) =>
          (value[key] ?? '').toString().trim().toLowerCase();
      final addressKeys = ['first_name', 'last_name', 'address_1', 'address_2', 'city', 'state', 'postcode', 'country'];
      final addressMatches = addressKeys.every((key) =>
          fieldValue(serverShipping, key) == fieldValue(selectedAddress, key));
      Map<String, dynamic> authoritativeCart = currentCart;
      if (!addressMatches) {
        authoritativeCart = await widget.api.updateCustomer(
          billing: selectedAddress,
          shipping: selectedAddress,
        );
        final verifiedShipping = authoritativeCart['shipping_address'] is Map
            ? Map<String, dynamic>.from(authoritativeCart['shipping_address'] as Map)
            : <String, dynamic>{};
        final verified = addressKeys.every((key) =>
            fieldValue(verifiedShipping, key) == fieldValue(selectedAddress, key));
        if (!verified) {
          throw Exception('WooCommerce could not save the selected delivery address. Please return to Address and try again.');
        }
      }
      if (authoritativeCart['items'] is List && (authoritativeCart['items'] as List).isEmpty) {
        throw Exception('Your WooCommerce cart is empty. Add a product before placing the order.');
      }
      if (authoritativeCart['totals'] is Map) {
        liveCart = Map<String, dynamic>.from(authoritativeCart);
      }

      // Billing email must match the signed-in WooCommerce account. The
      // selected delivery address remains the shipping address and may differ.
      final billingAddress = <String, dynamic>{...selectedAddress};
      final token = widget.customerToken;
      if (token != null && token.trim().isNotEmpty) {
        final profile = await ArkCustomerApi(token).request('customer/me');
        final accountEmail = profile is Map ? (profile['email'] ?? '').toString().trim() : '';
        if (accountEmail.isEmpty) {
          throw Exception('Your account email could not be verified. Open Account → Edit Profile, save a valid email, then retry checkout.');
        }
        billingAddress['email'] = accountEmail;
      }

      // The app collects payer proof only after the WooCommerce order is
      // created. The payer's own UPI address is intentionally not requested.
      const paymentData = <Map<String, dynamic>>[];
      final result = await widget.api.placeOrder(
        billing: billingAddress,
        shipping: selectedAddress,
        paymentMethod: selected!,
        paymentData: paymentData,
      );
      final orderId = WooStoreApi.confirmedOrderId(result);

      // Store API can create a valid guest order; attach it to the signed-in
      // customer using the Bridge's order-key + account-email ownership check
      // so it appears in My Orders. Never fabricate an order ID on attach error.
      var accountLinked = token == null || token.trim().isEmpty;
      String? accountLinkWarning;
      if (token != null && token.trim().isNotEmpty) {
        final orderKey = (result['order_key'] ?? result['key'] ?? '').toString();
        try {
          if (orderKey.isEmpty) throw Exception('WooCommerce did not return an order key.');
          final attached = await ArkCustomerApi(token).request(
            'orders/attach',
            method: 'POST',
            body: {'order_id': orderId, 'order_key': orderKey},
          );
          accountLinked = attached is Map &&
              attached['success'] == true &&
              int.tryParse('${attached['order_id'] ?? ''}') == orderId;
          if (!accountLinked) throw Exception('The store did not confirm linking this order to your account.');
        } catch (e) {
          accountLinkWarning = e.toString().replaceFirst('Exception: ', '');
        }
      }

      final resultWithTotals = <String, dynamic>{
        ...result,
        'order_id': orderId,
        'account_linked': accountLinked,
        if (accountLinkWarning != null) 'account_link_warning': accountLinkWarning,
        if (result['totals'] is! Map && liveCart['totals'] is Map)
          'totals': Map<String, dynamic>.from(liveCart['totals'] as Map),
      };
      if (selected == 'wc-upi') {
        final key = (resultWithTotals['order_key'] ?? resultWithTotals['key'] ?? '').toString();
        if (key.isEmpty) {
          throw Exception('WooCommerce created order #$orderId but did not return its verification key. Contact the store before paying.');
        }
        if (mounted) setState(() { createdOrder = resultWithTotals; paying = false; });
      } else {
        if (mounted) Navigator.pop(context, resultWithTotals);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && paying) setState(() => paying = false);
    }
  }

  Future<void> chooseScreenshot() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => error = 'Screenshot must be 5 MB or smaller.');
        return;
      }
      final lower = file.name.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') && !lower.endsWith('.png')) {
        setState(() => error = 'Choose a JPG or PNG payment screenshot.');
        return;
      }
      if (mounted) setState(() {
        screenshotBytes = bytes;
        screenshotName = file.name;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Could not open Gallery: $e');
    }
  }

  Future<void> submitUpi() async {
    final order = createdOrder;
    if (order == null) return;
    final id = int.tryParse('${order['order_id'] ?? order['id'] ?? ''}');
    final key = (order['order_key'] ?? order['key'] ?? '').toString();
    final utr = _utrController.text.replaceAll(RegExp(r'\D'), '');
    final utrMode = (upi['transaction_id_mode'] ?? 'show_require').toString();
    final imageMode = (upi['transaction_image_mode'] ?? 'show_require').toString();
    if (utrMode == 'show_require' && !RegExp(r'^\d{12}$').hasMatch(utr)) {
      setState(() => error = 'Enter the 12-digit UPI UTR / transaction ID.');
      return;
    }
    if (imageMode == 'show_require' && screenshotBytes == null) {
      setState(() => error = 'Please upload your UPI payment screenshot from Gallery.');
      return;
    }
    if (id == null || key.isEmpty) {
      setState(() => error = 'Order verification details are missing. Please contact the store.');
      return;
    }
    setState(() { submittingUpi = true; error = null; });
    try {
      final submitted = await widget.api.submitUpiPayment(
        orderId: id,
        orderKey: key,
        transactionId: utr,
        screenshotBytes: screenshotBytes,
        screenshotName: screenshotName,
      );
      final combined = <String, dynamic>{...order, ...submitted, 'order_id': id};
      if (mounted) Navigator.pop(context, combined);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => submittingUpi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        leading: IconButton(
          tooltip: 'Back to order details',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh payment methods',
            onPressed: paying || submittingUpi ? null : loadMethods,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          ...((liveCart['items'] as List? ?? []).whereType<Map>()).map((item) {
            final images = item['images'] as List? ?? const [];
            final image = images.isNotEmpty && images.first is Map
                ? (images.first['thumbnail'] ?? images.first['src'] ?? '').toString()
                : '';
            final line = item['totals'] is Map ? item['totals'] as Map : const {};
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: SizedBox(
                  width: 62, height: 62,
                  child: image.isEmpty
                    ? const Icon(Icons.shopping_bag_outlined)
                    : Image.network(image, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)),
                ),
                title: Text((item['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('Qty: ${item['quantity'] ?? 1}'),
                trailing: Text(money(line), style: const TextStyle(fontWeight: FontWeight.w800, color: _brand)),
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(color: const Color(0xFFF4F1FB), borderRadius: BorderRadius.circular(19)),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('STEP 3 OF 3', style: TextStyle(fontSize: 10, letterSpacing: 1.3, color: Color(0xFF51408F), fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Choose payment method', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Select a secure way to pay for your order.', style: TextStyle(color: Colors.black54, fontSize: 12))])),
              const Icon(Icons.verified_user_rounded, color: Color(0xFF51408F), size: 34),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Select how you want to pay for your order.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 18),
          if (createdOrder == null) ...[
            if (methods.isEmpty)
              _notice(error ?? 'No active payment methods were returned. Enable COD or UPI in WooCommerce and check the ARK Native API Bridge.', Icons.info_outline),

          ...methods.map((method) {
              final id = (method['id'] ?? '').toString();
              final active = selected == id;
              final isCod = id == 'cod';
              final isMethodUpi = id == 'wc-upi';
              return Card(
                elevation: active ? 3 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: active ? _brand : Colors.grey.shade200, width: active ? 1.7 : 1),
                ),
                child: RadioListTile<String>(
                  value: id,
                  groupValue: selected,
                  onChanged: paying ? null : (value) => setState(() { selected = value; error = null; }),
                  activeColor: _brand,
                  secondary: Container(
                    width: 54, height: 54,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: const Color(0xFFF3F0FA), borderRadius: BorderRadius.circular(15)),
                    child: Icon(isCod ? Icons.local_shipping_rounded : (isMethodUpi ? Icons.qr_code_2_rounded : Icons.account_balance_wallet_rounded), color: _brand, size: 29),
                  ),
                  title: Text((method['title'] ?? (isCod ? 'Cash on Delivery' : id)).toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text((method['description'] ?? (isCod ? 'Pay when your order is delivered' : 'Pay securely using your UPI app')).toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              );
            }),
          ] else ...[
            _upiInstructions(),
          ],
          const SizedBox(height: 18),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Payable amount', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(totals == null ? 'Amount unavailable' : money(totals), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _brand)),
              ]),
            ),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: _notice(error!, Icons.error_outline, isError: true)),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: paying || submittingUpi || (methods.isEmpty && createdOrder == null) || (createdOrder == null && totalMinor <= 0)
                  ? null
                  : (createdOrder == null ? placeOrder : submitUpi),
              style: FilledButton.styleFrom(backgroundColor: _brand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: paying || submittingUpi
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(createdOrder == null ? 'PLACE ORDER' : 'SUBMIT PAYMENT DETAILS', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upiInstructions() {
    final vpa = (upi['merchant_vpa'] ?? '').toString();
    final title = (upi['merchant_name'] ?? 'GlowHit Store').toString();
    final imageMode = (upi['transaction_image_mode'] ?? 'show_require').toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Pay using UPI', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (vpa.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: QrImageView(data: upiUri, version: QrVersions.auto, size: 210),
              ),
              const SizedBox(height: 10),
              SelectableText(vpa, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: vpa)),
                icon: const Icon(Icons.copy),
                label: const Text('COPY MERCHANT UPI ID'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(upiUri);
                  if (uri == null) return;
                  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!opened && mounted) {
                    await Clipboard.setData(ClipboardData(text: upiUri));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app opened. Payment link copied instead.')));
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('COPY UPI PAYMENT LINK'),
              ),
            ]),
          ),
        )
      else
        _notice('The store has not configured a merchant UPI address.', Icons.warning_amber),
      const SizedBox(height: 12),
      if ((upi['transaction_id_mode'] ?? 'show_require') != 'hide')
        TextField(
          controller: _utrController,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: const InputDecoration(labelText: 'UPI UTR / Transaction ID', hintText: 'Enter 12-digit UTR', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt_long)),
        ),
      OutlinedButton.icon(
        onPressed: submittingUpi ? null : chooseScreenshot,
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(screenshotBytes == null ? (imageMode == 'show_require' ? 'UPLOAD PAYMENT SCREENSHOT *' : 'UPLOAD PAYMENT SCREENSHOT') : 'SCREENSHOT SELECTED · CHANGE'),
      ),
      if (screenshotBytes != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(screenshotBytes!, height: 150, fit: BoxFit.contain)),
        ),
      const SizedBox(height: 8),
      const Text('Your order will remain On Hold until the store verifies your UPI payment. Submitting a UTR does not automatically mark the order as paid.', style: TextStyle(color: Colors.deepOrange, fontSize: 13)),
    ]);
  }

  Widget _notice(String message, IconData icon, {bool isError = false}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFFFFF1F0) : const Color(0xFFFFF7E8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isError ? Colors.red.shade100 : Colors.orange.shade100),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: isError ? Colors.red : Colors.deepOrange),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: TextStyle(color: isError ? Colors.red.shade800 : Colors.deepOrange.shade800))),
    ]),
  );
}
