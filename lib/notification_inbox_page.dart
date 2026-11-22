import 'package:flutter/material.dart';
import 'notification_service.dart';

const _purple = Color(0xFF51408F);

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key, required this.service});
  final GlowHitPushService service;
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
    try { final value = await widget.service.loadInbox(); if (mounted) setState(() { messages = value.take(6).toList(); loading = false; }); }
    catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); loading = false; }); }
  }
  Future<void> remove(Map<String, dynamic> item) async {
    final id = int.tryParse((item['id'] ?? '').toString());
    if (id == null) return;
    try { await widget.service.deleteMessage(id); if (mounted) setState(() => messages.removeWhere((m) => (m['id'] ?? '').toString() == id.toString())); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications'), actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : error != null
      ? Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('RETRY'))])))
      : messages.isEmpty ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.notifications_none, size: 54, color: _purple), SizedBox(height: 10), Text('You are all caught up!')]))
      : RefreshIndicator(onRefresh: load, child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: messages.length, itemBuilder: (context, index) {
        final item = messages[index];
        final type = (item['message_type'] ?? '').toString();
        final isOrder = type.startsWith('order_');
        final image = (item['image_url'] ?? '').toString();
        final link = (item['click_url'] ?? '').toString();
        return AnimatedBuilder(animation: _pulse, builder: (_, child) => Transform.translate(offset: Offset(0, index == 0 ? -_pulse.value * 1.5 : 0), child: child), child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => Navigator.pop(context, link),
            child: Padding(padding: const EdgeInsets.all(13), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(11), child: SizedBox(width: 62, height: 62, child: image.isEmpty ? Container(color: _purple.withValues(alpha: .10), child: Icon(isOrder ? Icons.local_shipping_outlined : Icons.campaign_outlined, color: _purple, size: 30)) : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.notifications)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((item['title'] ?? 'GlowHit update').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text((item['body'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text((item['sent_at'] ?? '').toString(), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              IconButton(tooltip: 'Delete', onPressed: () => remove(item), icon: const Icon(Icons.delete_outline, color: Colors.red)),
            ])),
          ),
        ));
      })),
  );
}
