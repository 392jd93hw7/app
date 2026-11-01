import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/anime.dart';
import '../services/anime_api.dart';
import '../widgets/anime_widgets.dart';

class AnimeDetailPage extends StatefulWidget {
  const AnimeDetailPage({
    super.key,
    required this.anime,
    required this.isSaved,
    required this.onSave,
    required this.onPlay,
  });
  final Anime anime;
  final bool isSaved;
  final VoidCallback onSave;
  final ValueChanged<int> onPlay;
  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  late bool saved;
  late Future<dynamic> _info;
  late Future<dynamic> _episodes;
  @override
  void initState() {
    super.initState();
    saved = widget.isSaved;
    _info = AnimeApi.getInfo(
      anilistId: widget.anime.source == 'anilist' ? widget.anime.id : null,
      malId: widget.anime.malId.isNotEmpty
          ? widget.anime.malId
          : (widget.anime.source == 'mal' ? widget.anime.id : null),
    );
    _episodes = AnimeApi.getEpisodes(
      animeId: widget.anime.id,
      source: widget.anime.source,
      malId: widget.anime.malId,
    );
  }

  void toggle() {
    setState(() => saved = !saved);
    widget.onSave();
  }

  List<dynamic> _episodeList(dynamic data) => AnimeApi.extractList(data);
  int _episodeNumber(dynamic item, int fallback) {
    if (item is Map) {
      return int.tryParse(
            (item['number'] ??
                    item['episode'] ??
                    item['ep'] ??
                    item['episodeNumber'] ??
                    fallback)
                .toString(),
          ) ??
          fallback;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 310,
          pinned: true,
          actions: [
            IconButton(
              onPressed: toggle,
              icon: Icon(
                saved ? Icons.bookmark : Icons.bookmark_border,
                color: appPurple,
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                AnimeCover(
                  widget.anime.banner.isNotEmpty
                      ? widget.anime.banner
                      : widget.anime.image,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, appBg],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.anime.year,
                        style: const TextStyle(color: appCyan),
                      ),
                      Text(
                        widget.anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.anime.format} • ${widget.anime.status} • ★ ${widget.anime.score}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => widget.onPlay(1),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Watch episode 1'),
                  ),
                ),
                FutureBuilder<dynamic>(
                  future: _info,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Additional metadata is unavailable.',
                        style: TextStyle(color: appMuted),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(color: appPurple),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Synopsis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.anime.synopsis.isEmpty
                      ? 'Synopsis not provided by the metadata source.'
                      : widget.anime.synopsis,
                  style: const TextStyle(color: appMuted, height: 1.5),
                ),
                if (widget.anime.genres.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: widget.anime.genres
                        .map((g) => Chip(label: Text(g)))
                        .toList(),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Episodes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                FutureBuilder<dynamic>(
                  future: _episodes,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(color: appPurple),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Could not load episode list: ${snapshot.error}',
                        style: const TextStyle(color: appMuted),
                      );
                    }
                    final episodes = _episodeList(snapshot.data);
                    if (episodes.isEmpty) {
                      final count = widget.anime.episodeCount;
                      if (count == null || count < 1) {
                        return const Text(
                          'No episode list was returned by the API.',
                          style: TextStyle(color: appMuted),
                        );
                      }
                      return Column(
                        children: List.generate(
                          count,
                          (i) => _episodeTile(i + 1, 'Episode ${i + 1}', ''),
                        ),
                      );
                    }
                    return Column(
                      children: episodes.asMap().entries.map((entry) {
                        final item = entry.value;
                        final number = _episodeNumber(item, entry.key + 1);
                        final title = item is Map
                            ? (item['title'] ??
                                      item['canonicalTitle'] ??
                                      item['name'] ??
                                      'Episode $number')
                                  .toString()
                            : 'Episode $number';
                        final synopsis = item is Map
                            ? (item['description'] ?? item['synopsis'] ?? '')
                                  .toString()
                            : '';
                        final thumbnail = item is Map
                            ? (item['thumbnail'] ?? '').toString()
                            : '';
                        return _episodeTile(number, title, synopsis, thumbnail);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _episodeNumberBadge(int number) => Container(
    width: 76,
    height: 48,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: appPurple.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$number',
      style: const TextStyle(color: appCyan, fontWeight: FontWeight.bold),
    ),
  );

  Widget _episodeTile(
    int number,
    String title,
    String synopsis, [
    String thumbnail = '',
  ]) => Card(
    color: appPanel,
    child: ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumbnail.isNotEmpty
            ? Image.network(
                thumbnail,
                width: 76,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _episodeNumberBadge(number),
              )
            : _episodeNumberBadge(number),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: synopsis.isEmpty
          ? null
          : Text(synopsis, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.play_circle_outline, color: appPurple),
      onTap: () => widget.onPlay(number),
    ),
  );
}
