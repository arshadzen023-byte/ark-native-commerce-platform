import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

const _brandPurple = Color(0xFF51408F);

class ProductDetailsPage extends StatelessWidget {
  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.onAddToCart,
    required this.onBuyNow,
    required this.isWishlisted,
    required this.onWishlist,
    this.floatingActionButton,
    this.appBar,
  });

  final Map<String, dynamic> product;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;
  final bool isWishlisted;
  final VoidCallback onWishlist;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;

  String _plainText(dynamic value) => (value ?? '')
      .toString()
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .trim();

  String _price() {
    final prices = product['prices'];
    if (prices is! Map) return '';
    final raw = int.tryParse('${prices['price'] ?? '0'}') ?? 0;
    final digits = (prices['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final divisor = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
    return '${prices['currency_symbol'] ?? '₹'}${(raw / divisor).toStringAsFixed(digits)}';
  }

  @override
  Widget build(BuildContext context) {
    final images = (product['images'] as List? ?? []).whereType<Map>().toList();
    final description = _plainText(product['description']);
    final shortDescription = _plainText(product['short_description']);
    final name = (product['name'] ?? 'Product').toString();
    return Scaffold(
      appBar: appBar ?? AppBar(
        title: const Text('Product details'),
        actions: [
          IconButton(onPressed: onWishlist, icon: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: isWishlisted ? Colors.red : null)),
          IconButton(onPressed: () => Share.share('$name\n${product['permalink'] ?? ''}'), icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 330,
              child: PageView(
                children: images.map((image) {
                  final src = (image['src'] ?? image['thumbnail'] ?? '').toString();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: src.isEmpty ? const Icon(Icons.image_outlined, size: 64) : Image.network(src, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 56)),
                  );
                }).toList(),
              ),
            )
          else
            Container(height: 280, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.image_outlined, size: 64)),
          const SizedBox(height: 20),
          Text(name, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_price(), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: _brandPurple)),
          if (shortDescription.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(shortDescription, style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Product description', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 15, height: 1.55)),
          ],
          if (product['sku'] != null && product['sku'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('SKU: ${product['sku']}', style: TextStyle(color: Colors.grey.shade700)),
          ],
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onAddToCart, icon: const Icon(Icons.shopping_cart_outlined), label: const Text('ADD TO CART'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: onBuyNow, style: FilledButton.styleFrom(backgroundColor: _brandPurple, minimumSize: const Size(0, 54)), child: const Text('BUY NOW'))),
          ]),
        ),
      ),
    );
  }
}
