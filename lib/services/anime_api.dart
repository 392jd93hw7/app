import 'dart:convert';
import 'dart:io';

import '../models/anime.dart';

/// Client-side metadata API. AniList is the primary source and Jikan is the
/// optional MyAnimeList metadata/episode source. No private backend is needed.
class AnimeApi {
  static const _aniListUrl = 'https://graphql.anilist.co';
  static const _jikanUrl = 'https://api.jikan.moe/v4';

  static const _mediaFields = '''
    id
    idMal
    title { english romaji native userPreferred }
    coverImage { large extraLarge }
    bannerImage
    averageScore
    seasonYear
    format
    status
    episodes
    description(asHtml: false)
    genres
    popularity
    nextAiringEpisode { airingAt episode }
  ''';

  static Future<dynamic> _request(Uri uri, {String method = 'GET', Object? body}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await (method == 'POST' ? client.postUrl(uri) : client.getUrl(uri))
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'AniScroll/1.0 (Flutter Android app)');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(const Duration(seconds: 30));
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('API request failed (HTTP ${response.statusCode}). ${text.length > 240 ? text.substring(0, 240) : text}', uri: uri);
      }
      if (text.isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded['errors'] is List && (decoded['errors'] as List).isNotEmpty) {
        throw HttpException('AniList: ${(decoded['errors'] as List).map((e) => e is Map ? e['message'] : e).join('; ')}', uri: uri);
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static Future<dynamic> _aniList(String query, [Map<String, dynamic> variables = const {}]) async {
    final result = await _request(Uri.parse(_aniListUrl), method: 'POST', body: {'query': query, 'variables': variables});
    return result is Map ? result['data'] : null;
  }

  static List<dynamic> extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['results', 'data', 'animes', 'episodes', 'items', 'media']) {
        final value = data[key];
        if (value is List) return value;
        if (value is Map) {
          for (final nested in ['results', 'items', 'data', 'episodes', 'media']) {
            if (value[nested] is List) return value[nested] as List<dynamic>;
          }
        }
      }
    }
    return const [];
  }

  static List<Anime> toAnimeList(dynamic data) => extractList(data)
      .whereType<Map>()
      .map((e) => Anime.fromJson(Map<String, dynamic>.from(e))).toList();

  static Future<List<Anime>> search(String query) async {
    final data = await _aniList('''
      query ($search: String) {
        Page(page: 1, perPage: 30) {
          media(search: $search, type: ANIME, sort: SEARCH_MATCH) { $_mediaFields }
        }
      }
    ''', {'search': query});
    final page = data is Map ? data['Page'] : null;
    return toAnimeList(page is Map ? page['media'] : null);
  }

  static String _currentSeason() {
    final month = DateTime.now().month;
    if (month >= 1 && month <= 3) return 'WINTER';
    if (month >= 4 && month <= 6) return 'SPRING';
    if (month >= 7 && month <= 9) return 'SUMMER';
    return 'FALL';
  }

  static Future<List<Anime>> season() async {
    final data = await _aniList('''
      query ($season: MediaSeason, $year: Int) {
        Page(page: 1, perPage: 50) {
          media(type: ANIME, season: $season, seasonYear: $year,
            sort: POPULARITY_DESC) { $_mediaFields }
        }
      }
    ''', {'season': _currentSeason(), 'year': DateTime.now().year});
    final page = data is Map ? data['Page'] : null;
    return toAnimeList(page is Map ? page['media'] : null);
  }

  static Future<List<dynamic>> airingSchedule() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final data = await _aniList('''
      query ($after: Int) {
        Page(page: 1, perPage: 50) {
          airingSchedules(airingAt_greater: $after, sort: TIME) {
            airingAt episode
            media { id idMal title { english romaji userPreferred } coverImage { large } format }
          }
        }
      }
    ''', {'after': now});
    final page = data is Map ? data['Page'] : null;
    return page is Map && page['airingSchedules'] is List
        ? page['airingSchedules'] as List<dynamic>
        : const [];
  }

  static Future<dynamic> topBanners() async => season();

  static Future<dynamic> getInfo({String? anilistId, String? malId}) async {
    if (anilistId != null && anilistId.isNotEmpty) {
      final data = await _aniList('''
        query ($id: Int) {
          Media(id: $id, type: ANIME) { $_mediaFields
            startDate { year month day }
            endDate { year month day }
            studios(isMain: true) { nodes { name } }
            relations { edges { relationTypeVersion node { id type title { userPreferred } } } }
            recommendations(perPage: 10, sort: RATING_DESC) { nodes { mediaRecommendation { id title { userPreferred } coverImage { large } averageScore } } }
          }
        }
      ''', {'id': int.tryParse(anilistId)});
      return data is Map ? data['Media'] : null;
    }
    if (malId != null && malId.isNotEmpty) {
      return _request(Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(malId)}/full'));
    }
    throw ArgumentError('An AniList ID or MAL ID is required.');
  }

  static Future<dynamic> getEpisodes({required String animeId, String source = 'anilist'}) async {
    final malId = int.tryParse(animeId);
    if (source == 'mal' && malId != null) {
      return _request(Uri.parse('$_jikanUrl/anime/$malId/episodes?page=1'));
    }
    // AniList does not publish episode titles. Return reliable episode numbers
    // from its metadata rather than inventing episode names or stream URLs.
    final info = await getInfo(anilistId: animeId);
    final count = info is Map ? int.tryParse('${info['episodes'] ?? ''}') : null;
    return {'data': List.generate(count != null && count > 0 && count <= 300 ? count : 0,
      (i) => {'number': i + 1, 'title': 'Episode ${i + 1}'})};
  }

  /// Streaming providers are intentionally separate from metadata APIs.
  /// Configure a licensed provider adapter before enabling playback.
  static Future<dynamic> getServers({required String animeId, required int episode, required String type, String source = 'anilist'}) {
    throw UnsupportedError('No authorized streaming provider is configured. Anime metadata and schedules work without a streaming backend.');
  }

  static Future<dynamic> watch({required String source, required String animeId, required int episode, required String type}) {
    throw UnsupportedError('No authorized streaming provider is configured.');
  }

  static Future<dynamic> health() async {
    final results = <String, dynamic>{};
    for (final entry in <String, Future<dynamic> Function()>{
      'AniList': () => _aniList('query { Viewer { id } }'),
      'Jikan': () => _request(Uri.parse('$_jikanUrl/anime/1')),
    }.entries) {
      try { await entry.value(); results[entry.key] = 'online'; }
      catch (e) { results[entry.key] = 'offline: $e'; }
    }
    return results;
  }

  static Future<dynamic> malAnime(String id) => _request(Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(id)}'));
  static Future<dynamic> malEpisodes(String id, {int page = 1}) => _request(Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(id)}/episodes?page=$page'));
  static Future<dynamic> malCharacters(String id) => _request(Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(id)}/characters'));
  static Future<dynamic> malRecommendations(String id) => _request(Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(id)}/recommendations'));
}
