import 'package:flutter/material.dart';
import 'designer_navigation_bar.dart';

const _fabPurple = Color(0xFF7650B8);
const _fabMuted = Color(0xFF77717F);
const _fabField = Color(0xFFF1EFF5);

class DesignerFloatingActionPagesPage extends StatefulWidget {
  const DesignerFloatingActionPagesPage({
    super.key,
    required this.availablePages,
    required this.configuredActions,
    required this.onEdit,
    required this.onRemove,
  });

  final List<Map<String, String>> availablePages;
  final Map<String, dynamic> configuredActions;
  final Future<void> Function(Map<String, String>) onEdit;
  final Future<void> Function(String) onRemove;

  @override
  State<DesignerFloatingActionPagesPage> createState() => _DesignerFloatingActionPagesPageState();
}

class _DesignerFloatingActionPagesPageState extends State<DesignerFloatingActionPagesPage> {
  Future<void> _remove(Map<String, String> page) async {
    final key = page['key']!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Floating Button?'),
        content: Text('Remove the Floating Action Button from ' + (page['title'] ?? key) + '?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onRemove(key);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Floating Action Button')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: widget.availablePages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final page = widget.availablePages[index];
          final key = page['key']!;
          final raw = widget.configuredActions[key];
          final action = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
          final configured = action.isNotEmpty;
          final enabled = configured && action['enabled'] == true;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _fabField,
                child: Icon(enabled ? Icons.flash_on_rounded : Icons.web_rounded,
                    color: enabled ? _fabPurple : _fabMuted),
              ),
              title: Text(page['title'] ?? key, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(!configured ? 'Not configured' : (enabled ? 'Floating button enabled' : 'Configured · disabled')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await widget.onEdit(page);
                if (mounted) setState(() {});
              },
              onLongPress: configured ? () => _remove(page) : null,
            ),
          );
        },
      ),
    );
  }
}

class DesignerFloatingActionSettingsPage extends StatefulWidget {
  const DesignerFloatingActionSettingsPage({
    super.key,
    required this.pageTitle,
    required this.initialConfig,
    required this.availablePages,
  });

  final String pageTitle;
  final Map<String, dynamic> initialConfig;
  final List<Map<String, String>> availablePages;

  @override
  State<DesignerFloatingActionSettingsPage> createState() => _DesignerFloatingActionSettingsPageState();
}

class _DesignerFloatingActionSettingsPageState extends State<DesignerFloatingActionSettingsPage> {
  late Map<String, dynamic> config;
  late final TextEditingController urlController;
  late final TextEditingController tooltipController;
  late final TextEditingController backgroundController;
  late final TextEditingController iconColorController;

  @override
  void initState() {
    super.initState();
    config = <String, dynamic>{
      'enabled': true,
      'icon_family': 'Material',
      'icon': 'add',
      'icon_color': '#FFFFFF',
      'background_color': '#5B3A9E',
      'size': 56,
      'margin_bottom': 16,
      'margin_right': 16,
      'link_type': 'in_app',
      'link_value': 'page:home',
      'tooltip': widget.pageTitle,
      ...widget.initialConfig,
    };
    urlController = TextEditingController(text: (config['link_value'] ?? '').toString());
    tooltipController = TextEditingController(text: (config['tooltip'] ?? '').toString());
    backgroundController = TextEditingController(text: (config['background_color'] ?? '#5B3A9E').toString());
    iconColorController = TextEditingController(text: (config['icon_color'] ?? '#FFFFFF').toString());
  }

  @override
  void dispose() {
    urlController.dispose();
    tooltipController.dispose();
    backgroundController.dispose();
    iconColorController.dispose();
    super.dispose();
  }

  Color _parseColor(String value, Color fallback) {
    final raw = value.replaceFirst('#', '').trim();
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return fallback;
    return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  Future<void> _chooseIcon() async {
    final selected = await Navigator.push<NavIconChoice>(
      context,
      MaterialPageRoute(builder: (_) => const DesignerFloatingIconPicker()),
    );
    if (selected == null || !mounted) return;
    setState(() {
      config['icon_family'] = selected.family;
      config['icon'] = selected.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final linkType = (config['link_type'] ?? 'in_app').toString();
    final validLinks = widget.availablePages.map((page) => 'page:' + page['key']!).toSet();
    var linkValue = (config['link_value'] ?? 'page:home').toString();
    if (linkType == 'in_app' && !validLinks.contains(linkValue)) linkValue = 'page:home';

    return Scaffold(
      appBar: AppBar(title: Text(widget.pageTitle + ' · Floating Button')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Enable Floating Action Button', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Show this button only on the selected page.'),
              value: config['enabled'] == true,
              activeColor: _fabPurple,
              onChanged: (value) => setState(() => config['enabled'] = value),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Button Icon', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _parseColor(backgroundController.text, _fabPurple),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: DesignerNavIcons.icon(
                      (config['icon_family'] ?? 'Material').toString(),
                      (config['icon'] ?? 'add').toString(),
                      color: _parseColor(iconColorController.text, Colors.white),
                      size: 26,
                    )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _chooseIcon,
                    icon: const Icon(Icons.apps_rounded),
                    label: const Text('Choose from Icon Library'),
                  )),
                ]),
                const SizedBox(height: 8),
                Text((config['icon_family'] ?? 'Material').toString() + ' · ' + (config['icon'] ?? 'add').toString(),
                    style: const TextStyle(color: _fabMuted, fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: backgroundController,
                  decoration: const InputDecoration(labelText: 'Button background colour (#RRGGBB)', border: OutlineInputBorder()),
                  onChanged: (value) => config['background_color'] = value.trim().toUpperCase(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: iconColorController,
                  decoration: const InputDecoration(labelText: 'Icon colour (#RRGGBB)', border: OutlineInputBorder()),
                  onChanged: (value) => config['icon_color'] = value.trim().toUpperCase(),
                ),
                const SizedBox(height: 14),
                Text('Button size · ' + config['size'].toString() + ' px'),
                Slider(
                  min: 40, max: 76, divisions: 18,
                  value: ((config['size'] as num?)?.toDouble() ?? 56).clamp(40.0, 76.0).toDouble(),
                  activeColor: _fabPurple,
                  onChanged: (value) => setState(() => config['size'] = value.round()),
                ),
                Text('Bottom offset · ' + config['margin_bottom'].toString() + ' px'),
                Slider(
                  min: 0, max: 120, divisions: 24,
                  value: ((config['margin_bottom'] as num?)?.toDouble() ?? 16).clamp(0.0, 120.0).toDouble(),
                  activeColor: _fabPurple,
                  onChanged: (value) => setState(() => config['margin_bottom'] = value.round()),
                ),
                Text('Right offset · ' + config['margin_right'].toString() + ' px'),
                Slider(
                  min: 0, max: 120, divisions: 24,
                  value: ((config['margin_right'] as num?)?.toDouble() ?? 16).clamp(0.0, 120.0).toDouble(),
                  activeColor: _fabPurple,
                  onChanged: (value) => setState(() => config['margin_right'] = value.round()),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Link / Destination', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: linkType,
                  decoration: const InputDecoration(labelText: 'Link type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'in_app', child: Text('Open app page')),
                    DropdownMenuItem(value: 'chrome', child: Text('Open website')),
                    DropdownMenuItem(value: 'deeplink', child: Text('App deep link')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      config['link_type'] = value;
                      config['link_value'] = value == 'in_app' ? 'page:home' : '';
                      urlController.text = config['link_value'].toString();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (linkType == 'in_app')
                  DropdownButtonFormField<String>(
                    value: linkValue,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Open page', border: OutlineInputBorder()),
                    items: widget.availablePages.map((page) => DropdownMenuItem(
                      value: 'page:' + page['key']!,
                      child: Text(page['title'] ?? page['key']!),
                    )).toList(),
                    onChanged: (value) => setState(() {
                      config['link_value'] = value ?? 'page:home';
                      urlController.text = config['link_value'].toString();
                    }),
                  )
                else
                  TextFormField(
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: linkType == 'chrome' ? 'HTTPS website URL' : 'App deep link',
                      hintText: linkType == 'chrome' ? 'https://example.com/page' : 'glowhit://page',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => config['link_value'] = value.trim(),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: tooltipController,
                  decoration: const InputDecoration(labelText: 'Accessibility label (optional)', border: OutlineInputBorder()),
                  onChanged: (value) => config['tooltip'] = value.trim(),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final target = (config['link_value'] ?? '').toString().trim();
                if (config['enabled'] == true && target.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a destination before enabling the button.')));
                  return;
                }
                if (config['link_type'] == 'chrome' &&
                    !RegExp(r'^https?://', caseSensitive: false).hasMatch(target)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid HTTP or HTTPS website URL.')));
                  return;
                }
                if (config['link_type'] == 'deeplink') {
                  final uri = Uri.tryParse(target);
                  if (uri == null || uri.scheme.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid app deep link.')));
                    return;
                  }
                }
                final bg = backgroundController.text.trim();
                final fg = iconColorController.text.trim();
                if (!RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(bg) ||
                    !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(fg)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid HEX colours such as #5B3A9E and #FFFFFF.')));
                  return;
                }
                config['background_color'] = bg.toUpperCase();
                config['icon_color'] = fg.toUpperCase();
                Navigator.pop(context, Map<String, dynamic>.from(config));
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save Floating Button'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, <String, dynamic>{'_remove': true}),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              label: const Text('Remove Floating Button', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}

class DesignerFloatingIconPicker extends StatefulWidget {
  const DesignerFloatingIconPicker({super.key});
  @override
  State<DesignerFloatingIconPicker> createState() => _DesignerFloatingIconPickerState();
}

class _DesignerFloatingIconPickerState extends State<DesignerFloatingIconPicker> {
  String query = '';
  String category = 'All';
  String family = 'All';

  @override
  Widget build(BuildContext context) {
    final icons = DesignerNavIcons.all.where((choice) {
      final text = (choice.name + ' ' + choice.label + ' ' + choice.family).toLowerCase();
      final matchesQuery = query.isEmpty || text.contains(query.toLowerCase());
      final matchesCategory = category == 'All' || DesignerNavIcons.categoryFor(choice) == category;
      final matchesFamily = family == 'All' || choice.family == family;
      return matchesQuery && matchesCategory && matchesFamily;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Floating Button Icon')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search icons', border: OutlineInputBorder()),
            onChanged: (value) => setState(() => query = value.trim()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: DesignerNavIcons.categories.map((value) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(label: Text(value), selected: category == value, onSelected: (_) => setState(() => category = value)),
            )).toList(),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: ['All', ...DesignerNavIcons.families].map((value) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(label: Text(value), selected: family == value, onSelected: (_) => setState(() => family = value)),
            )).toList(),
          ),
        ),
        Expanded(
          child: icons.isEmpty
              ? const Center(child: Text('No icons match this search.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: icons.length,
                  itemBuilder: (context, index) {
                    final choice = icons[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, choice),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          DesignerNavIcons.icon(choice.family, choice.name, color: _fabPurple, size: 27),
                          const SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Text(choice.label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
