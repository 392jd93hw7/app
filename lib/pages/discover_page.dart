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
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Anime> _results = [];
  bool _loading = false;
  String? _error;
  String _query = '';
  String _sort = 'POPULARITY_DESC';
  List<String> _genres = [];
  int? _year;
  String? _season;
  String? _format;
  String? _status;
  int _requestId = 0;

  static const _genreOptions = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 'Horror',
    'Mahou Shoujo', 'Mecha', 'Music', 'Mystery', 'Psychological',
    'Romance', 'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural',
    'Thriller',
  ];
  static const _sortOptions = {
    'POPULARITY_DESC': 'Popular',
    'SCORE_DESC': 'Top rated',
    'TRENDING_DESC': 'Trending',
    'START_DATE_DESC': 'Newest',
    'FAVOURITES_DESC': 'Most loved',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await AnimeApi.discover(
        search: _query,
        genres: _genres,
        year: _year,
        season: _season,
        format: _format,
        status: _status,
        sort: _sort,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = found;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Could not load anime. Please try again.';
      });
    }
  }

  void _onSearch(String value) {
    _query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> _openFilters() async {
    var genres = List<String>.from(_genres);
    var year = _year;
    var season = _season;
    var format = _format;
    var status = _status;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Filters', style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                        )),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(() {
                          genres = [];
                          year = null;
                          season = null;
                          format = null;
                          status = null;
                        }),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _filterHeading('Genres'),
                        Wrap(
                          spacing: 8, runSpacing: 2,
                          children: _genreOptions.map((genre) {
                            final selected = genres.contains(genre);
                            return FilterChip(
                              label: Text(genre),
                              selected: selected,
                              onSelected: (value) => setSheetState(() {
                                if (value) {
                                  genres.add(genre);
                                } else {
                                  genres.remove(genre);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        _filterHeading('Year'),
                        DropdownButtonFormField<int?>(
                          initialValue: year,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            filled: true, border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null, child: Text('Any year'),
                            ),
                            for (var y = DateTime.now().year + 1; y >= 1970; y--)
                              DropdownMenuItem<int?>(
                                value: y, child: Text('$y'),
                              ),
                          ],
                          onChanged: (value) => setSheetState(() => year = value),
                        ),
                        const SizedBox(height: 16),
                        _filterHeading('Season'),
                        Wrap(
                          spacing: 8,
                          children: ['WINTER', 'SPRING', 'SUMMER', 'FALL'].map((value) {
                            return ChoiceChip(
                              label: Text(value[0] + value.substring(1).toLowerCase()),
                              selected: season == value,
                              onSelected: (_) => setSheetState(
                                () => season = season == value ? null : value,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _filterHeading('Format'),
                        Wrap(
                          spacing: 8,
                          children: ['TV', 'TV_SHORT', 'MOVIE', 'OVA', 'ONA', 'SPECIAL'].map((value) {
                            return ChoiceChip(
                              label: Text(value.replaceAll('_', ' ')),
                              selected: format == value,
                              onSelected: (_) => setSheetState(
                                () => format = format == value ? null : value,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _filterHeading('Status'),
                        Wrap(
                          spacing: 8,
                          children: ['RELEASING', 'FINISHED', 'NOT_YET_RELEASED', 'CANCELLED'].map((value) {
                            final label = value == 'NOT_YET_RELEASED'
                                ? 'Upcoming'
                                : value.replaceAll('_', ' ').toLowerCase();
                            return ChoiceChip(
                              label: Text(label),
                              selected: status == value,
                              onSelected: (_) => setSheetState(
                                () => status = status == value ? null : value,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, {
                        'genres': genres,
                        'year': year,
                        'season': season,
                        'format': format,
                        'status': status,
                      }),
                      child: const Text('Show results'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _genres = List<String>.from(result['genres'] as List);
      _year = result['year'] as int?;
      _season = result['season'] as String?;
      _format = result['format'] as String?;
      _status = result['status'] as String?;
    });
    _load();
  }

  Widget _filterHeading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(text, style: const TextStyle(
      fontWeight: FontWeight.w700, fontSize: 15,
    )),
  );

  int get _activeFilterCount =>
      _genres.length + (_year == null ? 0 : 1) + (_season == null ? 0 : 1) +
      (_format == null ? 0 : 1) + (_status == null ? 0 : 1);

  void _clearFilters() {
    setState(() {
      _genres = [];
      _year = null;
      _season = null;
      _format = null;
      _status = null;
    });
    _load();
  }

  Future<void> _refresh() => _load();

  @override
  void dispose() {
    _requestId++;
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Discover', style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900,
                    )),
                    SizedBox(height: 3),
                    Text('Find your next favourite anime',
                      style: TextStyle(color: appMuted, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _load();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search anime, titles…',
                    prefixIcon: const Icon(Icons.search, color: appPurple),
                    suffixIcon: _query.isEmpty ? null : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        _query = '';
                        _load();
                        setState(() {});
                      },
                    ),
                    filled: true,
                    fillColor: appPanel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                height: 54,
                child: FilledButton.tonal(
                  onPressed: _openFilters,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 19),
                      if (_activeFilterCount > 0) ...[
                        const SizedBox(width: 5),
                        Text('$_activeFilterCount'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: _sortOptions.entries.map((entry) {
              final selected = _sort == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) {
                    if (_sort == entry.key) return;
                    setState(() => _sort = entry.key);
                    _load();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (_activeFilterCount > 0)
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                for (final genre in _genres)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(genre),
                      onDeleted: () {
                        setState(() => _genres.remove(genre));
                        _load();
                      },
                    ),
                  ),
                if (_year != null) _activeChip('$_year', () {
                  setState(() => _year = null); _load();
                }),
                if (_season != null) _activeChip(_season!, () {
                  setState(() => _season = null); _load();
                }),
                if (_format != null) _activeChip(_format!.replaceAll('_', ' '), () {
                  setState(() => _format = null); _load();
                }),
                if (_status != null) _activeChip(_status!.replaceAll('_', ' '), () {
                  setState(() => _status = null); _load();
                }),
                ActionChip(label: const Text('Clear all'), onPressed: _clearFilters),
              ],
            ),
          ),
        if (_loading) const LinearProgressIndicator(
          minHeight: 2, color: appPurple,
        ),
        Expanded(
          child: _error != null && _results.isEmpty
              ? _messageState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load Discover',
                  message: _error!,
                  action: 'Try again',
                  onAction: _load,
                )
              : _results.isEmpty && !_loading
                  ? _messageState(
                      icon: Icons.search_off_rounded,
                      title: 'No anime found',
                      message: 'Try another title or change your filters.',
                      action: 'Reset filters',
                      onAction: () {
                        _searchController.clear();
                        _query = '';
                        _sort = 'POPULARITY_DESC';
                        _clearFilters();
                      },
                    )
                  : RefreshIndicator(
                      color: appPurple,
                      onRefresh: _refresh,
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: .62,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (_, index) {
                          final anime = _results[index];
                          return AnimePoster(
                            anime: anime,
                            onTap: () => widget.onOpen(anime),
                          );
                        },
                      ),
                    ),
        ),
      ],
    ),
  );

  Widget _activeChip(String label, VoidCallback onDelete) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: InputChip(label: Text(label), onDeleted: onDelete),
  );

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
    required String action,
    required VoidCallback onAction,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: appMuted),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: appMuted)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}
