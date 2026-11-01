import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'anime_api.dart';

enum StreamFormat { hls, mp4 }

class StreamServer {
  const StreamServer(this.name);
  final String name;
}

class ResolvedStream {
  const ResolvedStream({
    required this.server,
    required this.uri,
    required this.format,
    this.subtitles = const [],
  });
  final String server;
  final Uri uri;
  final StreamFormat format;
  final List<Map<String, dynamic>> subtitles;
}

class StreamingService {
  static const requestTimeout = Duration(seconds: 15);
  static const validationTimeout = Duration(seconds: 12);
  static const headers = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://megaplay.buzz/',
    'Origin': 'https://megaplay.buzz',
    'Accept': '*/*',
  };

  Future<List<StreamServer>> getServers({
    required String animeId,
    String? malId,
    required int episode,
    required String type,
  }) async {
    debugPrint('[API] Request started: servers');
    final response = await AnimeApi.getServers(
      animeId: animeId, malId: malId, episode: episode, type: type, source: 'anikoto',
    ).timeout(requestTimeout);
    debugPrint('[API] Response received: servers');
    if (response is! Map || response['servers'] is! List) {
      throw const FormatException('Unexpected server-list response.');
    }
    final result = <StreamServer>[];
    final seen = <String>{};
    for (final item in response['servers'] as List) {
      if (item is Map) {
        final name = (item['name'] ?? '').toString().trim();
        if (name.isNotEmpty && seen.add(name)) {
          result.add(StreamServer(name));
        }
      }
    }
    if (result.isEmpty) throw const FormatException('No streaming servers were returned.');
    return result;
  }

  Future<ResolvedStream> resolve({
    required String animeId,
    String? malId,
    required int episode,
    required String type,
    required String server,
  }) async {
    debugPrint('[API] Request started: resolve $server');
    final response = await AnimeApi.watch(
      source: 'anikoto', animeId: animeId, malId: malId,
      episode: episode, type: type, server: server,
    ).timeout(requestTimeout);
    debugPrint('[API] Response received: resolve $server');
    if (response is! Map) {
      throw const FormatException('Watch API returned invalid JSON.');
    }
    if (response['iframeOnly'] == true) {
      throw const FormatException('This server is iframe-only; native playback is not supported.');
    }
    final returnedServer = (response['server'] ?? '').toString();
    if (returnedServer.isNotEmpty && returnedServer != server) {
      throw FormatException('Requested $server but API returned $returnedServer.');
    }

    final mode = (response['playbackMode'] ?? '').toString().toLowerCase();
    final proxy = response['hlsProxyUrl'];
    if (proxy is String && proxy.trim().isNotEmpty && (mode.isEmpty || mode == 'hls')) {
      final uri = _uri(proxy);
      await validateHls(uri);
      return ResolvedStream(
        server: server, uri: uri, format: StreamFormat.hls,
        subtitles: _subtitles(response['subtitles']),
      );
    }

    // MP4 is accepted only when explicitly advertised by the API.
    // The origin m3u8 field is never used as a fallback.
    final mp4 = response['mp4'];
    if (mode == 'mp4' && mp4 is String && mp4.trim().isNotEmpty) {
      return ResolvedStream(server: server, uri: _uri(mp4), format: StreamFormat.mp4,
        subtitles: _subtitles(response['subtitles']));
    }
    throw const FormatException('No supported hlsProxyUrl or explicit MP4 URL was returned.');
  }

  Uri _uri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty || !['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('Invalid playback URL.');
    }
    return uri;
  }

  Future<void> validateHls(Uri uri) async {
    final client = HttpClient()..connectionTimeout = validationTimeout;
    try {
      debugPrint('[SOURCE] Playlist validation started');
      final request = await client.getUrl(uri).timeout(validationTimeout);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(validationTimeout);
      final body = await response.transform(utf8.decoder).join().timeout(validationTimeout);
      debugPrint('[SOURCE] HTTP ${response.statusCode}; content-type=${response.headers.contentType}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HLS proxy returned HTTP ${response.statusCode}.', uri: uri);
      }
      if (!body.trimLeft().startsWith('#EXTM3U')) {
        final preview = body.length > 160 ? body.substring(0, 160) : body;
        throw FormatException('Proxy response is not an HLS playlist: ${preview.replaceAll(RegExp(r'\\s+'), ' ')}');
      }
      debugPrint('[SOURCE] Playlist contains #EXTM3U');
    } finally {
      client.close(force: true);
    }
  }

  List<Map<String, dynamic>> _subtitles(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).where((track) {
      final url = (track['url'] ?? '').toString();
      final lang = (track['lang'] ?? '').toString().toLowerCase();
      return url.startsWith('http') && lang != 'unknown' &&
          !url.toLowerCase().contains('thumbnails.vtt');
    }).toList();
  }
}
