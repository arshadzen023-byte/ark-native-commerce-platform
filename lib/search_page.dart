import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const _searchPurple = Color(0xFF51408F);
const _searchHistoryKey = 'glowhit_recent_searches';

class GlowHitSearchPage extends StatefulWidget {
  const GlowHitSearchPage({
    super.key,
    this.initialQuery = '',
    this.startVoice = false,
    required this.onOpenProduct,
  });

  final String initialQuery;
  final bool startVoice;
  final ValueChanged<Map<String, dynamic>> onOpenProduct;

  @override
  State<GlowHitSearchPage> createState() => _GlowHitSearchPageState();
}

class _GlowHitSearchPageState extends State<GlowHitSearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _speech = stt.SpeechToText();
  Timer? _debounce;
  List<String> _recent = [];
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _recommended = [];
  bool _loading = false;
  bool _editingRecent = false;
  bool _listening = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _controller.text = _query;
    _controller.addListener(_onQueryChanged);
    _loadRecent();
    if (widget.startVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startVoiceSearch());
    }
    if (_query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(_query, remember: true));
    } else {
      _loadRecommended();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focus.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _recent = prefs.getStringList(_searchHistoryKey) ?? []);
  }

  Future<void> _saveRecent(String value) async {
    final term = value.trim();
    if (term.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final next = <String>[term, ..._recent.where((e) => e.toLowerCase() != term.toLowerCase())].take(12).toList();
    await prefs.setStringList(_searchHistoryKey, next);
    if (mounted) setState(() => _recent = next);
  }

  Future<void> _removeRecent(String value) async {
    final next = _recent.where((e) => e != value).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, next);
    if (mounted) setState(() => _recent = next);
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
    if (mounted) setState(() { _recent = []; _editingRecent = false; });
  }

  void _onQueryChanged() {
    final value = _controller.text.trim();
    if (value == _query) return;
    setState(() { _query = value; _error = null; });
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() => _results = []);
      _loadRecommended();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 380), () => _search(value));
  }

  Uri _productsUri({String search = '', int limit = 12}) {
    final params = <String, String>{
      'per_page': '$limit',
      'orderby': 'popularity',
      'order': 'desc',
      '_fields': 'id,name,slug,permalink,images,prices,on_sale,average_rating,review_count,categories',
    };
    if (search.isNotEmpty) params['search'] = search;
    return Uri.parse('https://pluginstore.shop/wp-json/wc/store/v1/products').replace(queryParameters: params);
  }

  Future<void> _loadRecommended() async {
    if (_recommended.isNotEmpty) return;
    try {
      final response = await http.get(_productsUri(limit: 8), headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 18));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is List && mounted) {
        setState(() => _recommended = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
      }
    } catch (_) {}
  }

  Future<void> _search(String value, {bool remember = false}) async {
    final term = value.trim();
    if (term.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(_productsUri(search: term), headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('Search unavailable (HTTP ${response.statusCode}).');
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw const FormatException('Invalid product search response.');
      final rows = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() { _results = rows; _loading = false; });
      if (remember) await _saveRecent(term);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _submit([String? value]) async {
    final term = (value ?? _controller.text).trim();
    if (term.isEmpty) return;
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    _focus.unfocus();
    await _saveRecent(term);
    await _search(term);
  }

  Future<void> _startVoiceSearch() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) { if (mounted) setState(() => _listening = status == 'listening'); },
        onError: (error) { if (mounted) setState(() => _listening = false); },
      );
      if (!available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice Search is not available on this device.')));
        return;
      }
      final locales = await _speech.locales();
      String? localeId;
      for (final preferred in const ['en_IN', 'hi_IN']) {
        for (final locale in locales) {
          if (locale.localeId.toLowerCase() == preferred.toLowerCase()) { localeId = locale.localeId; break; }
        }
        if (localeId != null) break;
      }
      if (mounted) setState(() => _listening = true);
      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
        onResult: (result) {
          if (!mounted || result.recognizedWords.trim().isEmpty) return;
          _controller.text = result.recognizedWords.trim();
          if (result.finalResult) {
            setState(() => _listening = false);
            _submit();
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  String _image(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty && images.first is Map) {
      final image = images.first as Map;
      return (image['thumbnail'] ?? image['src'] ?? '').toString();
    }
    return '';
  }

  Widget _productTile(Map<String, dynamic> product) {
    final image = _image(product);
    final name = (product['name'] ?? 'Product').toString();
    final categories = product['categories'] is List
        ? (product['categories'] as List).whereType<Map>().map((e) => (e['name'] ?? '').toString()).where((e) => e.isNotEmpty).join(' · ')
        : '';
    return InkWell(
      onTap: () => widget.onOpenProduct(product),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 54, height: 58, color: const Color(0xFFF2F1F5),
              child: image.isEmpty ? const Icon(Icons.shopping_bag_outlined) : Image.network(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (categories.isNotEmpty) Text(categories, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _searchPurple, fontSize: 12)),
          ])),
          const Icon(Icons.north_west, color: Colors.black45, size: 18),
        ]),
      ),
    );
  }

  Widget _recentSection() {
    if (_recent.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Recent Searches', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
          TextButton(onPressed: () => setState(() => _editingRecent = !_editingRecent), child: Text(_editingRecent ? 'Done' : 'Edit')),
          if (_editingRecent) TextButton(onPressed: _clearRecent, child: const Text('Clear all')),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: _recent.map((term) => InputChip(
          avatar: const Icon(Icons.history, size: 17),
          label: Text(term, maxLines: 1, overflow: TextOverflow.ellipsis),
          onPressed: _editingRecent ? null : () => _submit(term),
          onDeleted: _editingRecent ? () => _removeRecent(term) : null,
        )).toList()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    final rows = hasQuery ? _results : _recommended;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        Container(
          color: const Color(0xFFD9E8FF),
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
          child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back)),
            Expanded(child: Container(
              height: 48,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFF8EACE0), width: 1.2)),
              child: Row(children: [
                const Padding(padding: EdgeInsets.only(left: 13, right: 8), child: Icon(Icons.search, color: Colors.black54)),
                Expanded(child: TextField(
                  controller: _controller, focusNode: _focus, autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submit,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search products, brands and more...', isDense: true),
                )),
                IconButton(tooltip: _listening ? 'Stop voice search' : 'Voice Search', onPressed: _listening ? () async { await _speech.stop(); if (mounted) setState(() => _listening = false); } : _startVoiceSearch, icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: _listening ? Colors.red : Colors.black87)),
                if (_controller.text.isNotEmpty) IconButton(tooltip: 'Clear', onPressed: () { _controller.clear(); _focus.requestFocus(); }, icon: const Icon(Icons.close)),
              ]),
            )),
          ]),
        ),
        Expanded(child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (!hasQuery) _recentSection(),
            if (!hasQuery && _recommended.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Text('Recommended Products', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            if (hasQuery && _results.isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text('Suggestions & Products', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (_error != null) Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            if (!_loading && hasQuery && _results.isEmpty && _error == null)
              const Padding(padding: EdgeInsets.all(24), child: Text('No matching products found. Try another search.')),
            ...rows.map(_productTile),
          ],
        )),
      ])),
    );
  }
}
