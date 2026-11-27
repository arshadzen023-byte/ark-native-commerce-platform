import 'package:flutter/material.dart';

import 'designer_app_bar.dart' show DesignerAppBarConfig;
import 'designer_navigation_bar.dart';

const _menuEditorAccent = Color(0xFF5B3A9E);

class DesignerAppBarMenuEditorPage extends StatefulWidget {
  const DesignerAppBarMenuEditorPage({
    super.key,
    required this.initialItems,
    required this.initialImageUrl,
    required this.initialImageId,
    required this.onUpload,
    required this.onChooseMedia,
  });

  final List<Map<String, dynamic>> initialItems;
  final String initialImageUrl;
  final int initialImageId;
  final Future<Map<String, dynamic>?> Function() onUpload;
  final Future<Map<String, dynamic>?> Function() onChooseMedia;

  @override
  State<DesignerAppBarMenuEditorPage> createState() => _DesignerAppBarMenuEditorPageState();
}

class _DesignerAppBarMenuEditorPageState extends State<DesignerAppBarMenuEditorPage> {
  late List<Map<String, dynamic>> items;
  late String imageUrl;
  late int imageId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    items = widget.initialItems.map((item) => Map<String, dynamic>.from(item)).toList();
    if (items.isEmpty) {
      items = DesignerAppBarConfig.defaultMenuItems
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    imageUrl = widget.initialImageUrl;
    imageId = widget.initialImageId;
  }

  Future<void> _selectImage({bool uploadFromPhone = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final media = uploadFromPhone ? await widget.onUpload() : await widget.onChooseMedia();
      if (media == null || !mounted) return;
      final url = (media['source_url'] ?? media['url'] ?? '').toString();
      final idValue = media['id'] ?? media['attachment_id'] ?? 0;
      final id = idValue is num ? idValue.toInt() : int.tryParse(idValue.toString()) ?? 0;
      if (url.isEmpty || id <= 0) {
        throw Exception('WordPress did not return a valid Media Library attachment ID and URL.');
      }
      setState(() {
        imageUrl = url;
        imageId = id;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Menu image selection failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _chooseIcon(int index, String field) async {
    final choice = await showDialog<NavIconChoice>(
      context: context,
      builder: (_) => const _MenuIconPicker(),
    );
    if (choice == null || !mounted) return;
    setState(() {
      items[index][field] = choice.name;
      items[index]['${field}_family'] = choice.family;
    });
  }

  void _save() {
    Navigator.pop(context, <String, dynamic>{
      'menu_items': items,
      'menu_header_image_url': imageUrl,
      'menu_header_image_id': imageId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Edit'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu Top Image · WordPress Media Library',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 70,
                          child: Center(child: Text('Image preview unavailable')),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => _selectImage(),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(imageUrl.isEmpty ? 'Choose from Media Library' : 'Replace from Media Library'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Upload from phone Gallery',
                        onPressed: busy ? null : () => _selectImage(uploadFromPhone: true),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      if (imageUrl.isNotEmpty)
                        IconButton(
                          tooltip: 'Remove image',
                          onPressed: () => setState(() {
                            imageUrl = '';
                            imageId = 0;
                          }),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                    ],
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (imageId > 0)
                    Text('WordPress Attachment ID: $imageId', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text('Default & Custom Menu Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: items.length >= 30
                    ? null
                    : () => setState(() {
                          items.add({
                            'id': DateTime.now().microsecondsSinceEpoch.toString(),
                            'title': 'New menu item',
                            'link_type': 'page',
                            'link_value': 'home',
                            'leading_icon_family': 'Material',
                            'leading_icon': 'home_outlined',
                            'leading_icon_style': 'plain',
                            'trailing_icon_family': 'Material',
                            'trailing_icon': 'chevron_right',
                            'visible': true,
                            'admin_only': false,
                          });
                        }),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
          for (var index = 0; index < items.length; index++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('menu-title-$index-${items[index]['id']}'),
                            initialValue: (items[index]['title'] ?? '').toString(),
                            decoration: const InputDecoration(labelText: 'Menu title'),
                            onChanged: (value) => items[index]['title'] = value,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete menu item',
                          onPressed: () => setState(() => items.removeAt(index)),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      value: (items[index]['link_type'] ?? 'page').toString(),
                      decoration: const InputDecoration(labelText: 'Destination type'),
                      items: const [
                        DropdownMenuItem(value: 'page', child: Text('App Page')),
                        DropdownMenuItem(value: 'url', child: Text('Website URL')),
                        DropdownMenuItem(value: 'deep_link', child: Text('Deep Link')),
                      ],
                      onChanged: (value) => setState(() => items[index]['link_type'] = value ?? 'page'),
                    ),
                    TextFormField(
                      key: ValueKey('menu-link-$index-${items[index]['id']}'),
                      initialValue: (items[index]['link_value'] ?? 'home').toString(),
                      decoration: const InputDecoration(labelText: 'Destination'),
                      onChanged: (value) => items[index]['link_value'] = value,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: DesignerNavIcons.icon(
                              (items[index]['leading_icon_family'] ?? 'Material').toString(),
                              (items[index]['leading_icon'] ?? 'home_outlined').toString(),
                              color: _menuEditorAccent,
                            ),
                            title: const Text('Leading icon'),
                            onTap: () => _chooseIcon(index, 'leading_icon'),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: DesignerNavIcons.icon(
                              (items[index]['trailing_icon_family'] ?? 'Material').toString(),
                              (items[index]['trailing_icon'] ?? 'chevron_right').toString(),
                              color: _menuEditorAccent,
                            ),
                            title: const Text('Trailing icon'),
                            onTap: () => _chooseIcon(index, 'trailing_icon'),
                          ),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      value: (items[index]['leading_icon_style'] ?? 'plain').toString(),
                      decoration: const InputDecoration(labelText: 'Leading icon style'),
                      items: const [
                        DropdownMenuItem(value: 'plain', child: Text('Plain')),
                        DropdownMenuItem(value: 'circle', child: Text('Circle')),
                        DropdownMenuItem(value: 'tile', child: Text('Colored tile')),
                      ],
                      onChanged: (value) => setState(() => items[index]['leading_icon_style'] = value ?? 'plain'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show this menu item'),
                      value: items[index]['visible'] != false,
                      onChanged: (value) => setState(() => items[index]['visible'] = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('WordPress administrators only'),
                      subtitle: const Text('Use for ARK Designer and other protected destinations.'),
                      value: items[index]['admin_only'] == true,
                      onChanged: (value) => setState(() => items[index]['admin_only'] = value),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Save Menu Settings')),
        ],
      ),
    );
  }
}

class _MenuIconPicker extends StatefulWidget {
  const _MenuIconPicker();
  @override
  State<_MenuIconPicker> createState() => _MenuIconPickerState();
}

class _MenuIconPickerState extends State<_MenuIconPicker> {
  String query = '';
  String family = 'All';

  @override
  Widget build(BuildContext context) {
    final icons = DesignerNavIcons.all.where((icon) {
      final familyMatches = family == 'All' || icon.family == family;
      final queryMatches = query.isEmpty || '${icon.name} ${icon.label}'.toLowerCase().contains(query.toLowerCase());
      return familyMatches && queryMatches;
    }).toList();
    return AlertDialog(
      title: const Text('Choose Menu Icon'),
      content: SizedBox(
        width: 360,
        height: 430,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search icons'),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: family,
              items: ['All', ...DesignerNavIcons.families].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => family = value ?? 'All'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                itemCount: icons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 5, mainAxisSpacing: 5),
                itemBuilder: (_, index) => InkWell(
                  onTap: () => Navigator.pop(context, icons[index]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DesignerNavIcons.icon(icons[index].family, icons[index].name, color: _menuEditorAccent, size: 23),
                      Text(icons[index].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
