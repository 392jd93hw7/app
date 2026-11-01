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

  static Future<dynamic> _request(
    Uri uri, {
    String method = 'GET',
    Object? body,
    String accept = 'application/json',
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request =
          await (method == 'POST' ? client.postUrl(uri) : client.getUrl(uri))
              .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, accept);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'AniScroll/1.0 (Flutter Android app)',
      );
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'API request failed (HTTP ${response.statusCode}). ${text.length > 240 ? text.substring(0, 240) : text}',
          uri: uri,
        );
      }
      if (text.isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map &&
          decoded['errors'] is List &&
          (decoded['errors'] as List).isNotEmpty) {
        throw HttpException(
          'AniList: ${(decoded['errors'] as List).map((e) => e is Map ? e['message'] : e).join('; ')}',
          uri: uri,
        );
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static Future<dynamic> _aniList(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final result = await _request(
      Uri.parse(_aniListUrl),
      method: 'POST',
      body: {'query': query, 'variables': variables},
    );
    return result is Map ? result['data'] : null;
  }

  static List<dynamic> extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in [
        'results',
        'data',
        'animes',
        'episodes',
        'items',
        'media',
      ]) {
        final value = data[key];
        if (value is List) return value;
        if (value is Map) {
          for (final nested in [
            'results',
            'items',
            'data',
            'episodes',
            'media',
          ]) {
            if (value[nested] is List) return value[nested] as List<dynamic>;
          }
        }
      }
    }
    return const [];
  }

  static List<Anime> toAnimeList(dynamic data) =>
      extractList(data)
          .whereType<Map>()
          .map((e) => Anime.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  static Future<List<Anime>> search(String query) async {
    final data = await _aniList(
      '''
      query (\$search: String) {
        Page(page: 1, perPage: 30) {
          media(search: \$search, type: ANIME, sort: SEARCH_MATCH) { $_mediaFields }
        }
      }
    ''',
      {'search': query},
    );
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
    final data = await _aniList(
      '''
      query (\$season: MediaSeason, \$year: Int) {
        Page(page: 1, perPage: 50) {
          media(type: ANIME, season: \$season, seasonYear: \$year,
            sort: POPULARITY_DESC) { $_mediaFields }
        }
      }
    ''',
      {'season': _currentSeason(), 'year': DateTime.now().year},
    );
    final page = data is Map ? data['Page'] : null;
    return toAnimeList(page is Map ? page['media'] : null);
  }

  static Future<List<dynamic>> airingSchedule() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final weekAgo = now - 7 * 24 * 60 * 60;
    final weekAhead = now + 7 * 24 * 60 * 60;
    final schedules = <dynamic>[];

    // AniList returns at most 50 entries per page. Fetch every page in the
    // two-week window so older aired episodes cannot crowd out upcoming days.
    for (var pageNumber = 1; pageNumber <= 20; pageNumber++) {
      final data = await _aniList(
        '''
        query (\$page: Int, \$after: Int, \$before: Int) {
          Page(page: \$page, perPage: 50) {
            airingSchedules(
              airingAt_greater: \$after,
              airingAt_lesser: \$before,
              sort: TIME
            ) {
              airingAt
              episode
              media {
                id
                idMal
                title { english romaji userPreferred }
                coverImage { large }
                format
              }
            }
          }
        }
      ''',
        {'page': pageNumber, 'after': weekAgo, 'before': weekAhead},
      );

      final page = data is Map ? data['Page'] : null;
      final entries = page is Map && page['airingSchedules'] is List
          ? page['airingSchedules'] as List<dynamic>
          : const <dynamic>[];
      schedules.addAll(entries);
      if (entries.length < 50) break;
    }

    return schedules;
  }

  static Future<dynamic> topBanners() async => season();

  static Future<dynamic> getInfo({String? anilistId, String? malId}) async {
    if (anilistId != null && anilistId.isNotEmpty) {
      final data = await _aniList(
        '''
        query (\$id: Int) {
          Media(id: \$id, type: ANIME) { $_mediaFields
            startDate { year month day }
            endDate { year month day }
            studios(isMain: true) { nodes { name } }
            relations { edges { relationType node { id type title { userPreferred } } } }
            recommendations(perPage: 10, sort: RATING_DESC) { nodes { mediaRecommendation { id title { userPreferred } coverImage { large } averageScore } } }
          }
        }
      ''',
        {'id': int.tryParse(anilistId)},
      );
      return data is Map ? data['Media'] : null;
    }
    if (malId != null && malId.isNotEmpty) {
      return _request(
        Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(malId)}/full'),
      );
    }
    throw ArgumentError('An AniList ID or MAL ID is required.');
  }

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
                          ? first['relationships']['item']['data']['id']
                                ?.toString()
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
            ? (thumbnail['original'] ??
                  thumbnail['large'] ??
                  thumbnail['small'])
            : thumbnail;
        final titles = attributes['titles'];
        final episodeTitle =
            attributes['canonicalTitle'] ??
            (titles is Map
                ? (titles['en_us'] ?? titles['en_jp'] ?? titles['ja_jp'])
                : null);
        episodes.add({
          'number': attributes['number'],
          'title': episodeTitle ?? '',
          'description':
              attributes['synopsis'] ?? attributes['description'] ?? '',
          'thumbnail': thumbnailUrl ?? '',
        });
      }
      if (page.length < pageSize) break;
    }
    return episodes;
  }

  static Future<List<dynamic>> _getMalEpisodes(String malId) async {
    final episodes = <dynamic>[];
    for (var page = 1; page <= 20; page++) {
      final response = await _request(
        Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(malId)}/episodes?page=$page'),
      );
      final pageItems = response is Map && response['data'] is List
          ? response['data'] as List<dynamic>
          : const <dynamic>[];
      episodes.addAll(pageItems);
      final pagination = response is Map && response['pagination'] is Map
          ? response['pagination'] as Map
          : const {};
      if (pagination['has_next_page'] != true || pageItems.isEmpty) break;
    }
    return episodes;
  }

  static Future<List<dynamic>> _getBackendEpisodes(String anilistId) async {
    final uri = Uri.parse(
      '$streamingBaseUrl/api/episodes?anilistId=${Uri.encodeComponent(anilistId)}',
    );
    final response = await _request(uri);
    if (response is! Map || response['episodes'] is! List) {
      return const [];
    }
    // This endpoint is used only for episode numbering and provider IDs.
    // Kitsu remains the sole source for episode titles, descriptions and artwork.
    return (response['episodes'] as List).whereType<Map>().map((item) {
      return {
        'number': item['num'] ?? item['number'] ?? item['episode'],
        // Preserve the provider episode ID for provider-aware playback.
        'id': item['id'],
      };
    }).toList();
  }

  static Future<dynamic> getEpisodes({
    required String animeId,
    String source = 'anilist',
    String? malId,
  }) async {
    const fastTimeout = Duration(seconds: 8);
    final isMalSource = source.toLowerCase() == 'mal';
    final resolvedMalId = (malId != null && malId.isNotEmpty)
        ? malId
        : (isMalSource ? animeId : '');
    final id = int.tryParse(animeId);

    // Keep MAL-native entries on Jikan, but don't let a slow Jikan response
    // prevent the streaming backend from supplying the episode numbers.
    if (isMalSource || id == null) {
      if (resolvedMalId.isNotEmpty) {
        try {
          final malEpisodes = await _getMalEpisodes(resolvedMalId)
              .timeout(fastTimeout);
          if (malEpisodes.isNotEmpty) {
            return {
              'data': malEpisodes.map((item) {
                final episode = item is Map ? item : const {};
                return {
                  'number': episode['mal_id'] ??
                      episode['episode'] ??
                      episode['episodeNumber'],
                  'title': episode['title'] ??
                      episode['title_japanese'] ??
                      episode['title_romanji'] ??
                      '',
                  'description': episode['synopsis'] ?? '',
                  'thumbnail': '',
                };
              }).toList(),
            };
          }
        } catch (_) {
          // Try the backend below.
        }
      }
      if (id == null) {
        if (resolvedMalId.isEmpty) {
          throw ArgumentError(
            'A numeric AniList ID or MAL ID is required to load episodes.',
          );
        }
        final backend = await _getBackendEpisodes(resolvedMalId)
            .timeout(fastTimeout);
        return {'data': backend};
      }
    }

    int? count;
    try {
      final data = await _aniList(
        '''
        query (\$id: Int) {
          Media(id: \$id, type: ANIME) {
            id
            episodes
          }
        }
      ''',
        {'id': id},
      ).timeout(fastTimeout);
      final media = data is Map ? data['Media'] : null;
      count = media is Map
          ? int.tryParse('${media['episodes'] ?? ''}')
          : null;
    } catch (_) {
      // AniList can be slow or temporarily unavailable; use backend numbering.
    }

    List<int> episodeNumbers = [];
    if (count != null && count > 0 && count <= 500) {
      episodeNumbers = List<int>.generate(count, (index) => index + 1);
    } else {
      // Backend episode data is the resilient numbering fallback even when
      // AniList fails or returns an unknown episode count.
      try {
        final backendEpisodes = await _getBackendEpisodes('$id')
            .timeout(fastTimeout);
        episodeNumbers = backendEpisodes
            .map((item) => int.tryParse('${item['number'] ?? ''}'))
            .whereType<int>()
            .where((number) => number > 0 && number <= 500)
            .toSet()
            .toList()
          ..sort();
      } catch (_) {
        // Continue to MAL fallback if available.
      }
      if (episodeNumbers.isEmpty && resolvedMalId.isNotEmpty) {
        try {
          final malEpisodes = await _getMalEpisodes(resolvedMalId)
              .timeout(fastTimeout);
          episodeNumbers = malEpisodes
              .map((item) => item is Map
                  ? int.tryParse('${item['mal_id'] ?? item['episode'] ?? ''}')
                  : null)
              .whereType<int>()
              .where((number) => number > 0 && number <= 500)
              .toSet()
              .toList()
            ..sort();
        } catch (_) {
          // No secondary source responded.
        }
      }
      if (episodeNumbers.isEmpty) {
        throw Exception(
          'AniList and the streaming backend did not return episode numbers.',
        );
      }
    }

    // Episode numbering is already available. Kitsu enriches the rows, but
    // its mapping/metadata requests are bounded so a slow Kitsu API cannot
    // make the entire episode section fail.
    List<dynamic> kitsuEpisodes = const [];
    try {
      kitsuEpisodes = await _getKitsuEpisodes('$id')
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Show numbered episodes with neutral fallback titles if Kitsu is slow.
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

    // Provider IDs are optional and never supply display metadata.
    final backendIds = <int, String>{};
    try {
      final backendEpisodes = await _getBackendEpisodes('$id')
          .timeout(fastTimeout);
      for (final item in backendEpisodes) {
        final number = int.tryParse('${item['number'] ?? ''}');
        final providerId = item['id']?.toString();
        if (number != null && providerId != null && providerId.isNotEmpty) {
          backendIds[number] = providerId;
        }
      }
    } catch (_) {
      // The list remains usable without provider IDs.
    }

    return {
      'data': episodeNumbers.map((number) {
        final kitsu = byNumber[number] ?? const <String, dynamic>{};
        final title = (kitsu['title'] ?? '').toString().trim();
        return {
          'number': number,
          'title': title.isEmpty ? 'Episode $number' : title,
          'description': kitsu['description'] ?? '',
          'thumbnail': kitsu['thumbnail'] ?? '',
          if (backendIds.containsKey(number)) 'id': backendIds[number],
        };
      }).toList(),
    };
  }

  // Streaming is resolved through the user's configured AniScroll API server.
  static const streamingBaseUrl = 'http://16.176.100.190:3000';

  static Future<dynamic> _streamRequest(String path) =>
      _request(Uri.parse('$streamingBaseUrl$path'));

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
      throw ArgumentError(
        'A numeric AniList ID or MAL ID is required for streaming.',
      );
    }
    return _streamRequest(
      '/api/servers?${Uri(queryParameters: queryParameters).query}',
    );
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
    final pathId = id != null
        ? '$id'
        : 'mal-${Uri.encodeComponent(malId ?? '')}';
    final uri = Uri(
      path:
          '/api/watch/${Uri.encodeComponent(source)}/$pathId/$episode/${Uri.encodeComponent(type)}',
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
      try {
        await entry.value();
        results[entry.key] = 'online';
      } catch (e) {
        results[entry.key] = 'offline: $e';
      }
    }
    return results;
  }

  static Future<dynamic> malAnime(String id) =>
      _request(Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(id)}'));
  static Future<dynamic> malEpisodes(String id, {int page = 1}) => _request(
    Uri.parse(
      '$_jikanUrl/anime/${Uri.encodeComponent(id)}/episodes?page=$page',
    ),
  );
  static Future<dynamic> malCharacters(String id) => _request(
    Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(id)}/characters'),
  );
  static Future<dynamic> malRecommendations(String id) => _request(
    Uri.parse('$_jikanUrl/anime/${Uri.encodeComponent(id)}/recommendations'),
  );
}
