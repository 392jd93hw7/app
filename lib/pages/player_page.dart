import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/theme.dart';
import '../models/anime.dart';
import '../services/anime_api.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.anime, required this.episode});
  final Anime anime;
  final int episode;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _controller;
  List<_StreamSource> _sources = [];
  int _selectedSource = 0;
  bool _loading = true, _controlsVisible = true, _fullscreen = false;
  bool _subtitles = true;
  String _error = '', _streamType = 'sub';
  double _speed = 1;
  Timer? _hideTimer;
  bool _autoFallbackInProgress = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadSources();
  }

  Future<void> _loadSources() async {
    if (mounted) {
      setState(() { _loading = true; _error = ''; });
    }
    try {
      // "anilist" is the metadata source, not a streaming provider.
      // The streaming API expects a provider such as anikoto or animeheaven.
      final response = await AnimeApi.getServers(
        animeId: widget.anime.id,
        malId: widget.anime.malId,
        episode: widget.episode,
        type: _streamType,
        source: 'anikoto',
      );

      final servers = response is Map && response['servers'] is List
          ? response['servers'] as List
          : const [];
      final sources = <_StreamSource>[];

      // /api/servers returns sourceId values, not playable URLs. Resolve each
      // server by name through /api/watch/{source}/{id}/{ep}/{type}?server=...
      for (final item in servers) {
        if (item is! Map) {
          continue;
        }
        final serverName = (item['name'] ?? '').toString();
        if (serverName.isEmpty) {
          continue;
        }
        try {
          final streamResponse = await AnimeApi.watch(
            source: 'anikoto',
            animeId: widget.anime.id,
            malId: widget.anime.malId,
            episode: widget.episode,
            type: _streamType,
            server: serverName,
          );
          final resolved = _extractSources(streamResponse, serverName);
          sources.addAll(resolved);
        } catch (_) {
          // Try the next available server if this provider fails.
        }
      }

      final uniqueUrls = <String>{};
      final playable = sources.where((source) => uniqueUrls.add(source.url)).toList();
      if (playable.isEmpty) {
        throw Exception('No playable stream was returned. The server list loaded, but every /api/watch request failed or returned no M3U8/MP4 URL.');
      }
      if (!mounted) {
        return;
      }
      setState(() => _sources = playable);
      final started = await _tryServersFrom(0);
      if (started) {
        return;
      }
      const lastError = 'Every available server failed to start playback.';
      throw Exception(lastError ?? 'Every available server failed.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  List<_StreamSource> _extractSources(dynamic value, String serverName) {
    final found = <_StreamSource>[];
    void walk(dynamic node, [String name = 'Server']) {
      if (node is List) {
        for (final item in node) { walk(item, name); }
      } else if (node is Map) {
        final label = (node['name'] ?? node['provider'] ?? node['server'] ?? node['source'] ?? name).toString();
        // Try the backend proxy first, then retain the origin URL as a fallback.
        final candidates = <String>[
          for (final key in ['hlsProxyUrl', 'url', 'file', 'link', 'src', 'streamUrl', 'm3u8', 'mp4', 'hls'])
            if (node[key] is String) (node[key] as String),
        ];
        var extracted = false;
        for (final url in candidates) {
          final isHttp = url.startsWith('http://') || url.startsWith('https://');
          final isMedia = url.contains('.m3u8') || url.contains('.mp4') ||
              node['type'] == 'hls' || node['type'] == 'mp4' ||
              node['isM3U8'] == true || node['playbackMode'] == 'hls';
          if (isHttp && isMedia) {
            found.add(_StreamSource(
              url == node['hlsProxyUrl'] ? '$serverName (Proxy)' : '$serverName (Direct)',
              url,
              serverName,
            ));
            extracted = true;
          }
        }
        if (!extracted) {
          for (final entry in node.entries) {
            if (entry.value is Map || entry.value is List) {
              walk(entry.value, entry.key.toString());
            }
          }
        }
      }
    }
    walk(value);
    final unique = <String>{};
    return found.where((source) => unique.add(source.url)).toList();
  }

  Future<bool> _tryServersFrom(int startIndex) async {
    Object? lastError;
    final attemptedServers = <String>{};
    for (var i = startIndex; i < _sources.length; i++) {
      final serverName = _sources[i].serverName;
      if (!attemptedServers.add(serverName)) {
        continue;
      }
      try {
        await _playSource(i);
        return true;
      } catch (error) {
        lastError = error;
      }
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _error = lastError?.toString().replaceFirst('Exception: ', '') ??
            'No other streaming servers are available.';
      });
    }
    return false;
  }

  void _handlePlaybackUpdate(VideoPlayerController controller, int index) {
    if (!mounted ||
        !identical(_controller, controller) ||
        !controller.value.hasError ||
        _autoFallbackInProgress) {
      return;
    }
    _autoFallbackInProgress = true;
    final failedServer = _sources[index].serverName;
    // Start at the next different server, skipping alternate URLs from the
    // failed server (for example HD-1 Direct after HD-1 Proxy).
    var nextIndex = index + 1;
    while (nextIndex < _sources.length &&
        _sources[nextIndex].serverName == failedServer) {
      nextIndex++;
    }
    if (nextIndex >= _sources.length) {
      nextIndex = 0;
      while (nextIndex < _sources.length &&
          _sources[nextIndex].serverName == failedServer) {
        nextIndex++;
      }
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _error = 'Server $failedServer failed. Trying another server…';
      });
    }
    Future<void>(() async {
      final started = nextIndex < _sources.length
          ? await _tryServersFrom(nextIndex)
          : false;
      if (!started && mounted) {
        setState(() {
          _loading = false;
          _error = 'Playback failed on $failedServer and no fallback server worked.';
        });
      }
      _autoFallbackInProgress = false;
    });
  }

  Future<void> _playSource(int index) async {
    final source = _sources[index];
    VideoPlayerController? next;
    try {
      final uri = Uri.parse(source.url);
      if (!uri.hasScheme || !['http', 'https'].contains(uri.scheme)) {
        throw Exception('Invalid video URL');
      }
      next = VideoPlayerController.networkUrl(uri, httpHeaders: const {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': 'https://megaplay.buzz/',
        'Origin': 'https://megaplay.buzz',
        'Accept': '*/*',
      });
      await next.initialize().timeout(const Duration(seconds: 35));
      await next.setLooping(false);
      await next.setPlaybackSpeed(_speed);
      if (!mounted) {
        await next.dispose();
        return;
      }
      final previous = _controller;
      setState(() { _controller = next; _selectedSource = index; _loading = false; _error = ''; });
      next.addListener(() => _handlePlaybackUpdate(next!, index));
      await next.play();
      await previous?.dispose();
      _scheduleHide();
    } catch (_) {
      await next?.dispose();
      rethrow;
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    }
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    if (_fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    if (mounted) {
      setState(() {});
    }
  }

  String _time(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}' : '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen ? null : AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_sources.isNotEmpty) PopupMenuButton<int>(
            tooltip: 'Change server', icon: const Icon(Icons.dns_outlined),
            onSelected: (index) async {
              setState(() => _loading = true);
              try { await _playSource(index); } catch (_) {
                await _tryServersFrom(index + 1);
              }
            },
            itemBuilder: (_) => _sources.asMap().entries.map((entry) => PopupMenuItem(
              value: entry.key,
              child: Row(children: [
                if (entry.key == _selectedSource) const Icon(Icons.check, color: appPurple, size: 18),
                const SizedBox(width: 8), Text(entry.value.name),
              ]),
            )).toList(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.closed_caption_outlined),
            onSelected: (value) {
              if (value == 'toggle') {
                setState(() => _subtitles = !_subtitles);
              }
              if (value == 'type') { setState(() => _streamType = _streamType == 'sub' ? 'dub' : 'sub'); _loadSources(); }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'toggle', child: Text(_subtitles ? 'Subtitle preference: on' : 'Subtitle preference: off')),
              PopupMenuItem(value: 'type', child: Text(_streamType == 'sub' ? 'Switch to dub servers' : 'Switch to sub servers')),
            ],
          ),
        ],
      ),
      body: SafeArea(child: Column(children: [
        Expanded(child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(alignment: Alignment.center, children: [
            if (video != null && video.value.isInitialized)
              Center(child: AspectRatio(aspectRatio: video.value.aspectRatio, child: VideoPlayer(video)))
            else
              const Center(child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 76)),
            if (_loading) const CircularProgressIndicator(color: appPurple),
            if (_error.isNotEmpty && !_loading) Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 38),
                const SizedBox(height: 12),
                Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: _loadSources, icon: const Icon(Icons.refresh), label: const Text('Retry servers')),
              ]),
            ),
            if (_controlsVisible && video != null && video.value.isInitialized && !_loading) _buildControls(video),
          ]),
        )),
        if (!_fullscreen) _buildEpisodeFooter(),
      ])),
    );
  }

  Widget _buildControls(VideoPlayerController video) {
    final value = video.value;
    return Container(
      color: Colors.black.withValues(alpha: .38),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text('EP ${widget.episode}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          PopupMenuButton<double>(
            initialValue: _speed, color: const Color(0xFF202033),
            onSelected: (speed) { setState(() => _speed = speed); video.setPlaybackSpeed(speed); },
            itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                .map((speed) => PopupMenuItem<double>(
                      value: speed,
                      child: Text(
                        '${speed}x',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ))
                .toList(),
            child: Text('${_speed}x', style: const TextStyle(color: Colors.white)),
          ),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => video.seekTo(value.position - const Duration(seconds: 10)), icon: const Icon(Icons.replay_10, color: Colors.white, size: 34)),
          const SizedBox(width: 24),
          IconButton(onPressed: () => value.isPlaying ? video.pause() : video.play(), iconSize: 58, icon: Icon(value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white)),
          const SizedBox(width: 24),
          IconButton(onPressed: () => video.seekTo(value.position + const Duration(seconds: 10)), icon: const Icon(Icons.forward_10, color: Colors.white, size: 34)),
        ]),
        Column(children: [
          VideoProgressIndicator(video, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 8), colors: const VideoProgressColors(playedColor: appPurple, bufferedColor: Colors.white38, backgroundColor: Colors.white12)),
          Row(children: [
            Text(_time(value.position), style: const TextStyle(color: Colors.white, fontSize: 11)),
            const Spacer(),
            Text(_time(value.duration), style: const TextStyle(color: Colors.white, fontSize: 11)),
            IconButton(onPressed: _toggleFullscreen, icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white)),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildEpisodeFooter() => Container(
    width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    color: const Color(0xFF10111C),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.anime.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 4),
      Text('Episode ${widget.episode} • ${_sources.isEmpty ? 'Finding servers…' : _sources[_selectedSource].name}', style: const TextStyle(color: appMuted)),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.subtitles_outlined, color: appPurple, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_subtitles ? 'Subtitle preference: English (if provided by stream)' : 'Subtitle preference: off', style: const TextStyle(color: appMuted, fontSize: 12))),
        TextButton(onPressed: () { setState(() => _streamType = _streamType == 'sub' ? 'dub' : 'sub'); _loadSources(); }, child: Text(_streamType.toUpperCase())),
      ]),
    ]),
  );
}

class _StreamSource {
  const _StreamSource(this.name, this.url, this.serverName);
  final String name, url, serverName;
}
