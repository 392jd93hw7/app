import 'dart:convert';
import 'dart:io';

import '../models/anime.dart';

class AnimeApi {
  static const baseUrl = 'http://16.176.100.190:3000';

  static Future<dynamic> get(String path) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.partialContent) {
        var message = 'API returned HTTP ${response.statusCode}';
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final error = decoded['error']?.toString();
            final detail = decoded['detail']?.toString();
            if (error != null && error.isNotEmpty) message = error;
            if (detail != null && detail.isNotEmpty) message = '$message: $detail';
          }
        } on FormatException {}
        throw HttpException(message, uri: Uri.parse('$baseUrl$path'));
      }
      if (body.isEmpty) return null;
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
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

  static Future<List<Anime>> search(String query) async =>
      toAnimeList(await get('/api/search?q=${Uri.encodeQueryComponent(query)}'));

  static Future<List<Anime>> season() async => toAnimeList(await get('/api/anilist/season'));
  static Future<dynamic> topBanners() => get('/api/anilist/top-banners');

  static Future<dynamic> getInfo({String? anilistId, String? malId}) {
    final q = <String, String>{
      if (anilistId != null && anilistId.isNotEmpty) 'anilistId': anilistId,
      if (malId != null && malId.isNotEmpty) 'malId': malId,
    };
    return get('/api/info?${Uri(queryParameters: q).query}');
  }

  static Future<dynamic> getEpisodes({required String animeId, String source = 'anilist'}) {
    final q = Uri(queryParameters: {'id': animeId, 'source': source}).query;
    return get('/api/episodes?$q');
  }

  static Future<dynamic> getServers({required String animeId, required int episode, required String type, String source = 'anilist'}) {
    final q = Uri(queryParameters: {'id': animeId, 'anilistId': animeId, 'ep': '$episode', 'type': type, 'source': source}).query;
    return get('/api/servers?$q');
  }

  static Future<dynamic> watch({required String source, required String animeId, required int episode, required String type}) =>
      get('/api/watch/${Uri.encodeComponent(source)}/${Uri.encodeComponent(animeId)}/$episode/${Uri.encodeComponent(type)}');

  static Future<dynamic> health() => get('/api/health');
  static Future<dynamic> malAnime(String id) => get('/api/mal/anime/${Uri.encodeComponent(id)}');
  static Future<dynamic> malEpisodes(String id, {int page = 1}) => get('/api/mal/anime/${Uri.encodeComponent(id)}/episodes?page=$page');
  static Future<dynamic> malCharacters(String id) => get('/api/mal/anime/${Uri.encodeComponent(id)}/characters');
  static Future<dynamic> malRecommendations(String id) => get('/api/mal/anime/${Uri.encodeComponent(id)}/recommendations');
}
