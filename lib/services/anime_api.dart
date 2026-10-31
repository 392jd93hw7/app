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
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw HttpException('API returned HTTP ${response.statusCode}');
      }
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<Anime>> search(String query) async {
    final data = await get('/api/search?q=${Uri.encodeQueryComponent(query)}');
    final list = data is List
        ? data
        : data is Map
            ? (data['results'] ?? data['data'] ?? data['animes'] ?? [])
            : [];
    return list is List
        ? list.whereType<Map>().map((item) => Anime.fromJson(Map<String, dynamic>.from(item))).toList()
        : [];
  }

  static Future<dynamic> getServers({
    required String animeId,
    required int episode,
    required String type,
    String source = 'anilist',
  }) {
    final query = <String, String>{
      'id': animeId,
      'anilistId': animeId,
      'ep': episode.toString(),
      'type': type,
      'source': source,
    };
    return get('/api/servers?${Uri(queryParameters: query).query}');
  }
}