class Anime {
  const Anime(
    this.id,
    this.title,
    this.image, {
    this.score = '—',
    this.year = '',
    this.synopsis = '',
    this.genres = const [],
    this.banner = '',
    this.source = 'anilist',
    this.malId = '',
    this.format = '',
    this.status = '',
    this.episodeCount,
    this.popularity,
  });

  final String id, title, image, score, year, synopsis, banner, source;
  final String malId, format, status;
  final List<String> genres;
  final int? episodeCount, popularity;

  factory Anime.fromJson(Map<String, dynamic> j) {
    final rawTitle = j['title'] ?? j['titles'];
    final title = rawTitle is Map
        ? (rawTitle['english'] ?? rawTitle['romaji'] ?? rawTitle['userPreferred'] ?? rawTitle['name'] ?? rawTitle['native'] ?? 'Anime').toString()
        : (rawTitle ?? j['name'] ?? j['englishTitle'] ?? 'Anime').toString();
    final cover = j['coverImage'] ?? j['cover_image'];
    final coverUrl = cover is Map ? (cover['extraLarge'] ?? cover['large'] ?? cover['medium']) : cover;
    final bannerValue = j['bannerImage'] ?? j['banner'] ?? j['backdrop'];
    final image = j['image'] ?? j['poster'] ?? j['posterUrl'] ?? j['thumbnail'] ?? j['cover'] ?? coverUrl ?? '';
    final id = j['anilistId'] ?? j['aniListId'] ?? j['id'] ?? j['malId'] ?? j['mal_id'] ?? title;
    final score = j['score'] ?? j['averageScore'] ?? j['mean'] ?? j['rating'] ?? '—';
    final yearValue = j['year'] ?? j['seasonYear'] ?? j['startDate']?['year'] ?? '';
    final synopsis = j['synopsis'] ?? j['description'] ?? j['overview'] ?? '';
    final genresValue = j['genres'] ?? j['genre'];
    return Anime(
      id.toString(), title, image.toString(),
      score: score.toString(),
      year: yearValue.toString(),
      synopsis: synopsis.toString(),
      genres: genresValue is List ? genresValue.map((e) => e is Map ? (e['name'] ?? '').toString() : e.toString()).where((e) => e.isNotEmpty).toList() : const [],
      banner: (bannerValue ?? '').toString(),
      source: (j['source'] ?? (j['malId'] != null ? 'mal' : 'anilist')).toString(),
      malId: (j['malId'] ?? j['mal_id'] ?? '').toString(),
      format: (j['format'] ?? j['type'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      episodeCount: int.tryParse((j['episodes'] ?? j['episodeCount'] ?? '').toString()),
      popularity: int.tryParse((j['popularity'] ?? '').toString()),
    );
  }
}
