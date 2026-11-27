import 'package:flutter/material.dart';
import 'notification_service.dart';

const _purple = Color(0xFF51408F);

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key, required this.service, this.floatingActionButton, this.appBar});
  final GlowHitPushService service;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  @override State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  List<Map<String, dynamic>> messages = [];
  bool loading = true;
  String? error;

  @override void initState() { super.initState(); load(); }
  @override void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final value = await widget.service.loadInbox();
      final valid = value.where((item) {
        final title = (item['title'] ?? '').toString().trim();
        final body = (item['body'] ?? '').toString().trim();
        final id = int.tryParse((item['id'] ?? '').toString()) ?? 0;
        return id > 0 && title.isNotEmpty && body.isNotEmpty;
      }).toList();
      if (mounted) setState(() { messages = valid.take(6).toList(); loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; });
    }
  }

  String _destination(Map<String, dynamic> item) {
    final link = (item['click_url'] ?? '').toString().trim();
    if (link.isNotEmpty) return link;
    final type = (item['target_type'] ?? '').toString();
    final id = int.tryParse((item['target_id'] ?? '').toString()) ?? 0;
    if (id < 1) return '';
    switch (type) {
      case 'order': return 'ark://orders/$id';
      case 'product': return 'ark://product/$id';
      case 'page': return 'ark://page/$id';
      case 'category': return 'ark://category/$id';
      default: return '';
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final id = int.tryParse((item['id'] ?? '').toString()) ?? 0;
    final link = _destination(item);
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This notification has no valid destination.')));
      return;
    }
    try {
      if (id > 0) await widget.service.recordClick(id);
    } catch (_) {
      // Navigation remains available even if click analytics is temporarily offline.
    }
    if (mounted) Navigator.pop(context, link);
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final id = int.tryParse((item['id'] ?? '').toString());
    if (id == null || id < 1) return;
    try {
      await widget.service.deleteMessage(id);
      if (mounted) setState(() => messages.removeWhere((m) => (m['id'] ?? '').toString() == id.toString()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Widget _orderLeading() => Container(
    width: 76, height: 76,
    decoration: BoxDecoration(color: _purple.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
    child: const Icon(Icons.local_shipping_outlined, color: _purple, size: 39),
  );

  Widget _saleBanner(String image) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: _purple.withValues(alpha: .05),
        child: Image.network(
          image,
          width: double.infinity,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 36, color: _purple)),
        ),
      ),
    ),
  );

  @override Widget build(BuildContext context) => Scaffold(
    appBar: widget.appBar ?? AppBar(title: const Text('Notifications'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: widget.floatingActionButton,
    body: loading
      ? const Center(child: CircularProgressIndicator())
      : error != null
        ? Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('RETRY'))])))
        : messages.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.notifications_none, size: 54, color: _purple), SizedBox(height: 10), Text('You are all caught up!')]))
          : RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final item = messages[index];
                final type = (item['message_type'] ?? '').toString();
                final isOrder = type == 'order_placed' || type == 'order_status';
                final image = (item['image_url'] ?? '').toString().trim();
                final title = (item['title'] ?? '').toString().trim();
                final body = (item['body'] ?? '').toString().trim();
                final date = (item['sent_at'] ?? '').toString();
                return AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, index == 0 ? -_pulse.value * 1.2 : 0),
                    child: child,
                  ),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(item),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (!isOrder && image.isNotEmpty) ...[
                            _saleBanner(image),
                            const SizedBox(height: 11),
                          ],
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (isOrder) ...[_orderLeading(), const SizedBox(width: 12)],
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 5),
                              Text(body, maxLines: 4, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Text(date, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ])),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => remove(item),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
