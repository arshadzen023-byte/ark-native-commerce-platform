import 'package:flutter/material.dart';

class OrderSummaryPage extends StatelessWidget {
  const OrderSummaryPage({super.key, required this.cart, required this.onContinue, this.onQuantityChanged, this.onRemove});
  final Map<String, dynamic> cart;
  final VoidCallback onContinue;
  final Future<void> Function(String key, int quantity)? onQuantityChanged;
  final Future<void> Function(String key)? onRemove;

  String money(dynamic data) {
    if (data is! Map) return '';
    final raw = int.tryParse('${data['total_price'] ?? data['line_total'] ?? '0'}') ?? 0;
    final digits = (data['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
    return '${data['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = (cart['items'] as List? ?? []).whereType<Map>().toList();
    final totals = cart['totals'] is Map ? cart['totals'] as Map : const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Order summary')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Review your order', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${items.length} product${items.length == 1 ? '' : 's'} in your cart', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 14),
        ...items.map((item) {
          final images = item['images'] as List? ?? [];
          final image = images.isNotEmpty && images.first is Map
              ? (images.first['thumbnail'] ?? images.first['src'] ?? '').toString()
              : '';
          final lineTotals = item['totals'] is Map ? item['totals'] : null;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: SizedBox(width: 64, height: 64, child: image.isEmpty
                  ? const Icon(Icons.shopping_bag_outlined)
                  : Image.network(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined))),
              title: Text((item['name'] ?? 'Product').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Unit price: ${money(item['prices'] is Map ? item['prices'] : lineTotals)}'),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(visualDensity: VisualDensity.compact, onPressed: onQuantityChanged == null ? null : () => onQuantityChanged!((item['key'] ?? '').toString(), ((item['quantity'] as num?)?.toInt() ?? 1) - 1), icon: const Icon(Icons.remove_circle_outline)),
                  Text('${item['quantity'] ?? 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(visualDensity: VisualDensity.compact, onPressed: onQuantityChanged == null ? null : () => onQuantityChanged!((item['key'] ?? '').toString(), ((item['quantity'] as num?)?.toInt() ?? 1) + 1), icon: const Icon(Icons.add_circle_outline)),
                  TextButton(onPressed: onRemove == null ? null : () => onRemove!((item['key'] ?? '').toString()), child: const Text('Remove')),
                ]),
              ]),
              trailing: Text(money(lineTotals), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }),
        const SizedBox(height: 10),
        _row('Subtotal', money({'total_price': totals['total_items'], 'currency_symbol': totals['currency_symbol'], 'currency_minor_unit': totals['currency_minor_unit']})),
        _row('Tax', money({'total_price': totals['total_tax'], 'currency_symbol': totals['currency_symbol'], 'currency_minor_unit': totals['currency_minor_unit']})),
        _row('Shipping', money({'total_price': totals['total_shipping'], 'currency_symbol': totals['currency_symbol'], 'currency_minor_unit': totals['currency_minor_unit']})),
        _row('Discount', money({'total_price': totals['total_discount'], 'currency_symbol': totals['currency_symbol'], 'currency_minor_unit': totals['currency_minor_unit']})),
        const Divider(height: 26),
        _row('Order total', money(totals), bold: true),
        const SizedBox(height: 22),
        SizedBox(height: 54, child: FilledButton(onPressed: items.isEmpty ? null : onContinue, child: const Text('CONTINUE TO ADDRESS', style: TextStyle(fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 15)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 15)),
    ]),
  );
}
