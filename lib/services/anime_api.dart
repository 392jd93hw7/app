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

  static Future<dynamic> _request(Uri uri, {String method = 'GET', Object? body, String accept = 'application/json'}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await (method == 'POST' ? client.postUrl(uri) : client.getUrl(uri))
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, accept);
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
      query (\$search: String) {
        Page(page: 1, perPage: 30) {
          media(search: \$search, type: ANIME, sort: SEARCH_MATCH) { $_mediaFields }
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
      query (\$season: MediaSeason, \$year: Int) {
        Page(page: 1, perPage: 50) {
          media(type: ANIME, season: \$season, seasonYear: \$year,
            sort: POPULARITY_DESC) { $_mediaFields }
        }
      }
    ''', {'season': _currentSeason(), 'year': DateTime.now().year});
    final page = data is Map ? data['Page'] : null;
    return toAnimeList(page is Map ? page['media'] : null);
  }

  static Future<List<dynamic>> airingSchedule() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final weekAgo = now - 7 * 24 * 60 * 60;
    final weekAhead = now + 7 * 24 * 60 * 60;
    final data = await _aniList('''
      query (\$after: Int, \$before: Int) {
        Page(page: 1, perPage: 50) {
          airingSchedules(airingAt_greater: \$after, airingAt_lesser: \$before, sort: TIME) {
            airingAt episode
            media { id idMal title { english romaji userPreferred } coverImage { large } format }
          }
        }
      }
    ''', {'after': weekAgo, 'before': weekAhead});
    final page = data is Map ? data['Page'] : null;
    return page is Map && page['airingSchedules'] is List
        ? page['airingSchedules'] as List<dynamic>
        : const [];
  }

  static Future<dynamic> topBanners() async => season();

  static Future<dynamic> getInfo({String? anilistId, String? malId}) async {
    if (anilistId != null && anilistId.isNotEmpty) {
      final data = await _aniList('''
        query (\$id: Int) {
          Media(id: \$id, type: ANIME) { $_mediaFields
            startDate { year month day }
            endDate { year month day }
            studios(isMain: true) { nodes { name } }
            relations { edges { relationType node { id type title { userPreferred } } } }
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

  static const _kitsuUrl = 'https://kitsu.io/api/edge';

  static Future<List<dynamic>> _getKitsuEpisodes(String anilistId) async {
    // Kitsu exposes cross-service mappings. Resolve the Kitsu anime ID using
    // AniList's ID rather than relying on a title search that can mis-match sequels.
    final mappingUri = Uri.https('kitsu.io', '/api/edge/mappings', {
      'filter[externalSite]': 'anilist/anime',
      'filter[externalId]': anilistId,
      'include': 'item',
    });
    final mapping = await _request(
      mappingUri,
      accept: 'application/vnd.api+json',
    );
    final mappings = mapping is Map && mapping['data'] is List
        ? mapping['data'] as List
        : const [];
    if (mappings.isEmpty) return const [];
    final first = mappings.first;
    final kitsuId = first is Map
        ? first['relationships'] is Map
            ? (first['relationships']['item'] is Map
                ? first['relationships']['item']['data'] is Map
                    ? first['relationships']['item']['data']['id']?.toString()
                    : null
                : null)
            : null
        : null;
    if (kitsuId == null || kitsuId.isEmpty) return const [];

    final episodes = <dynamic>[];
    const pageSize = 20;
    for (var offset = 0; offset < 500; offset += pageSize) {
      final uri = Uri.https('kitsu.io', '/api/edge/anime/$kitsuId/episodes', {
        'page[limit]': '$pageSize',
        'page[offset]': '$offset',
        'sort': 'number',
      });
      final response = await _request(uri, accept: 'application/vnd.api+json');
      final page = response is Map && response['data'] is List
          ? response['data'] as List
          : const [];
      if (page.isEmpty) break;
      for (final raw in page) {
        if (raw is! Map) continue;
        final attributes = raw['attributes'];
        if (attributes is! Map) continue;
        final thumbnail = attributes['thumbnail'];
        final thumbnailUrl = thumbnail is Map
            ? (thumbnail['original'] ?? thumbnail['large'] ?? thumbnail['small'])
            : thumbnail;
        episodes.add({
          'number': attributes['number'],
          'title': attributes['canonicalTitle'] ??
              attributes['titles'] is Map
                  ? (attributes['canonicalTitle'] ??
                      (attributes['titles'] as Map)['en_us'] ??
                      (attributes['titles'] as Map)['en_jp'])
                  : attributes['canonicalTitle'],
          'description': attributes['synopsis'] ?? attributes['description'] ?? '',
          'thumbnail': thumbnailUrl ?? '',
        });
      }
      if (page.length < pageSize) break;
    }
    return episodes;
  }

  static Future<dynamic> getEpisodes({required String animeId, String source = 'anilist', String? malId}) async {
    final id = int.tryParse(animeId);
    if (id == null) {
      throw ArgumentError('A numeric AniList ID is required to load the episode list.');
    }

    // AniList is the source of truth for the episode count/number sequence.
    // Kitsu enriches those numbered episodes with titles, thumbnails and synopsis.
    final data = await _aniList('''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          id
          episodes
        }
      }
    ''', {'id': id});
    final media = data is Map ? data['Media'] : null;
    final count = media is Map ? int.tryParse('${media['episodes'] ?? ''}') : null;
    if (count == null || count < 1 || count > 500) {
      throw Exception('AniList did not return a valid episode count for this anime.');
    }

    List<dynamic> kitsuEpisodes = const [];
    try {
      kitsuEpisodes = await _getKitsuEpisodes('$id');
    } catch (_) {
      // Keep the AniList episode list usable when Kitsu has no mapping or is down.
    }
    final byNumber = <int, Map<String, dynamic>>{};
    for (final item in kitsuEpisodes) {
      if (item is Map) {
        final number = int.tryParse('${item['number'] ?? ''}');
        if (number != null) {
          byNumber.putIfAbsent(number, () => Map<String, dynamic>.from(item));
        }
      }
    }
    return {
      'data': List.generate(count, (index) {
        final number = index + 1;
        final kitsu = byNumber[number] ?? const <String, dynamic>{};
        final title = (kitsu['title'] ?? '').toString().trim();
        return {
          'number': number,
          'title': title.isEmpty ? 'Episode $number' : title,
          'description': kitsu['description'] ?? '',
          'thumbnail': kitsu['thumbnail'] ?? '',
        };
      }),
    };
  }

  // Streaming is resolved through the user's configured AniScroll API server.
  static const streamingBaseUrl = 'http://16.176.100.190:3000';

  static Future<dynamic> _streamRequest(String path) => _request(Uri.parse('$streamingBaseUrl$path'));

  static Future<dynamic> getServers({
    required String animeId,
    String? malId,
    required int episode,
    required String type,
    String source = 'anikoto',
  }) {
    final id = int.tryParse(animeId);
    final mal = int.tryParse(malId ?? '');
    final queryParameters = <String, String>{
      if (id != null) 'anilistId': '$id',
      if (id == null && mal != null) 'malId': '$mal',
      'ep': '$episode',
      'type': type,
      'source': source,
    };
    if (id == null && mal == null) {
      throw ArgumentError('A numeric AniList ID or MAL ID is required for streaming.');
    }
    return _streamRequest('/api/servers?${Uri(queryParameters: queryParameters).query}');
  }

  static Future<dynamic> watch({
    required String source,
    required String animeId,
    String? malId,
    required int episode,
    required String type,
    String? server,
  }) {
    final id = int.tryParse(animeId);
    final pathId = id != null ? '$id' : 'mal-${Uri.encodeComponent(malId ?? '')}';
    final uri = Uri(
      path: '/api/watch/${Uri.encodeComponent(source)}/$pathId/$episode/${Uri.encodeComponent(type)}',
      queryParameters: server == null ? null : {'server': server},
    );
    return _streamRequest(uri.toString());
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
