import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/anime.dart';
import '../services/anime_api.dart';
import '../widgets/anime_widgets.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.onOpen});
  final ValueChanged<Anime> onOpen;
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final controller = TextEditingController();
  Timer? debounce;
  List<Anime> results = [];
  bool loading = false;
  String? error;
  String query = '';

  void search(String value) {
    query = value.trim();
    debounce?.cancel();
    if (query.isEmpty) { setState(() { results = []; error = null; loading = false; }); return; }
    debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() { loading = true; error = null; });
      try {
        final found = await AnimeApi.search(query);
        if (mounted) setState(() { results = found; loading = false; });
      } catch (e) {
        if (mounted) setState(() { results = []; loading = false; error = 'Search failed: $e'; });
      }
    });
  }

  @override
  void dispose() { debounce?.cancel(); controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    const Padding(padding: EdgeInsets.all(18), child: Align(alignment: Alignment.centerLeft, child: Text('Discover', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
      controller: controller, onChanged: search,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(hintText: 'Search anime titles…', prefixIcon: const Icon(Icons.search, color: appPurple), suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { controller.clear(); search(''); }), filled: true, fillColor: appPanel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
    )),
    if (loading) const LinearProgressIndicator(color: appPurple),
    if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
    Expanded(child: query.isEmpty
      ? const Center(child: Text('Search by anime title or alternate title.', style: TextStyle(color: appMuted)))
      : results.isEmpty && !loading
        ? const Center(child: Text('No matching anime found.', style: TextStyle(color: appMuted)))
        : GridView.builder(padding: const EdgeInsets.all(14), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .62, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: results.length, itemBuilder: (_, i) => AnimePoster(anime: results[i], onTap: () => widget.onOpen(results[i]))),
    ),
  ]));
}
