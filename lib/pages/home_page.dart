import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/anime.dart';
import '../services/anime_api.dart';
import '../widgets/anime_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onOpen, required this.history});
  final ValueChanged<Anime> onOpen;
  final List<Anime> history;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Anime>> _season;
  @override
  void initState() { super.initState(); _season = AnimeApi.season(); }
  Future<void> _refresh() async { setState(() => _season = AnimeApi.season()); await _season; }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.play_circle_fill, color: appPurple, size: 32),
            const SizedBox(width: 9),
            const Text('AniScroll', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const Spacer(),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ]),
        )),
        if (widget.history.isNotEmpty)
          SliverToBoxAdapter(child: AnimeSection(title: 'Continue watching', child: AnimeRail(items: widget.history, onOpen: widget.onOpen))),
        SliverToBoxAdapter(child: FutureBuilder<List<Anime>>(
          future: _season,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: appPurple)));
            }
            if (snapshot.hasError) {
              return Padding(padding: const EdgeInsets.all(20), child: Text('Could not load anime from the API. ${snapshot.error}', style: const TextStyle(color: appMuted)));
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Padding(padding: EdgeInsets.all(20), child: Text('No seasonal anime returned by the API.', style: TextStyle(color: appMuted)));
            }
            final featured = items.first;
            return Column(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GestureDetector(
                onTap: () => widget.onOpen(featured),
                child: ClipRRect(borderRadius: BorderRadius.circular(22), child: SizedBox(
                  height: 290,
                  child: Stack(fit: StackFit.expand, children: [
                    AnimeCover(featured.banner.isNotEmpty ? featured.banner : featured.image),
                    const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, appBg]))),
                    Positioned(left: 18, right: 18, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('✦ FEATURED', style: TextStyle(color: appCyan, fontWeight: FontWeight.bold)),
                      Text(featured.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                      Text('${featured.format} • ${featured.year} • ★ ${featured.score}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      FilledButton.icon(onPressed: () => widget.onOpen(featured), icon: const Icon(Icons.info_outline), label: const Text('View anime')),
                    ])),
                  ]),
                )),
              )),
              AnimeSection(title: 'Trending this season', child: AnimeRail(items: items, onOpen: widget.onOpen)),
              AnimeSection(title: 'Popular this season', child: AnimeRail(items: items.reversed.toList(), onOpen: widget.onOpen)),
              AnimeSection(title: 'Recommendations', child: AnimeRail(items: items, onOpen: widget.onOpen)),
            ]);
          },
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    ),
  );
}
