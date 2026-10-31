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
  List<String> _servers = [];
  final List<String> _failures = [];
  int _selected = -1, _generation = 0;
  bool _loading = true, _controls = true, _fullscreen = false, _switching = false, _captions = true;
  String _type = 'sub', _status = 'Finding servers…';
  String? _error, _currentServer;
  double _speed = 1;
  Timer? _hideTimer;

  static const _headers = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://megaplay.buzz/',
    'Origin': 'https://megaplay.buzz',
    'Accept': '*/*',
  };

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadServers();
  }

  Future<void> _loadServers({int start = 0}) async {
    final generation = ++_generation;
    _failures.clear();
    setState(() {
      _loading = true;
      _error = null;
      _status = 'Finding $_type servers…';
      _servers = [];
      _selected = -1;
    });
    try {
      final result = await AnimeApi.getServers(
        animeId: widget.anime.id,
        malId: widget.anime.malId,
        episode: widget.episode,
        type: _type,
        source: 'anikoto',
      );
      if (!mounted || generation != _generation) return;
      final list = result is Map && result['servers'] is List ? result['servers'] as List : const [];
      final names = <String>[];
      for (final item in list) {
        if (item is Map) {
          final name = (item['name'] ?? '').toString().trim();
          if (name.isNotEmpty && !names.contains(name)) names.add(name);
        }
      }
      if (names.isEmpty) throw Exception('The API returned no streaming servers.');
      setState(() => _servers = names);
      await _tryFrom(start, generation);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() { _loading = false; _error = _message(e); });
      }
    }
  }

  String? _proxyFrom(dynamic value) {
    if (value is List) {
      for (final item in value) {
        final url = _proxyFrom(item);
        if (url != null) return url;
      }
    } else if (value is Map) {
      final raw = value['hlsProxyUrl'];
      if (raw is String && raw.trim().isNotEmpty) {
        final uri = Uri.tryParse(raw.trim());
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
          return raw.trim();
        }
      }
      for (final child in value.values) {
        if (child is Map || child is List) {
          final url = _proxyFrom(child);
          if (url != null) return url;
        }
      }
    }
    return null;
  }

  Future<bool> _tryFrom(int start, int generation) async {
    for (var i = start; i < _servers.length; i++) {
      if (!mounted || generation != _generation) return false;
      final server = _servers[i];
      setState(() { _loading = true; _error = null; _status = 'Resolving $server HLS proxy…'; });
      try {
        final response = await AnimeApi.watch(
          source: 'anikoto',
          animeId: widget.anime.id,
          malId: widget.anime.malId,
          episode: widget.episode,
          type: _type,
          server: server,
        );
        if (!mounted || generation != _generation) return false;
        final proxy = _proxyFrom(response);
        if (proxy == null) throw Exception('Server did not return hlsProxyUrl.');
        setState(() => _status = 'Opening $server…');
        await _start(proxy, server, i, generation);
        return true;
      } catch (e) {
        final detail = '$server: ${_message(e)}';
        _failures.add(detail);
        debugPrint('AniScroll player: $detail');
      }
    }
    if (mounted && generation == _generation) {
      setState(() {
        _loading = false;
        _error = ['All streaming servers failed.', ..._failures, 'Direct M3U8 fallback is disabled.'].join('\n\n');
      });
    }
    return false;
  }

  Future<void> _start(String url, String server, int index, int generation) async {
    VideoPlayerController? next;
    try {
      next = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _headers,
        formatHint: VideoFormat.hls,
      );
      await next.initialize().timeout(const Duration(seconds: 40));
      if (!mounted || generation != _generation) {
        await next.dispose();
        return;
      }
      await next.setLooping(false);
      await next.setPlaybackSpeed(_speed);
      final previous = _controller;
      setState(() {
        _controller = next;
        _selected = index;
        _currentServer = server;
        _loading = false;
        _error = null;
        _status = 'Playing';
      });
      next.addListener(() => _onVideoUpdate(next!, generation));
      await next.play();
      await previous?.dispose();
      _scheduleHide();
    } catch (e) {
      await next?.dispose();
      rethrow;
    }
  }

  void _onVideoUpdate(VideoPlayerController controller, int generation) {
    if (!mounted || generation != _generation || !identical(controller, _controller) ||
        !controller.value.hasError || _switching) return;
    _switching = true;
    final nextIndex = _selected + 1;
    setState(() { _loading = true; _status = '$_currentServer failed. Trying next server…'; });
    unawaited(() async {
      await controller.dispose();
      if (mounted && identical(_controller, controller)) setState(() => _controller = null);
      await _tryFrom(nextIndex, generation);
      _switching = false;
    }());
  }

  Future<void> _chooseServer(int index) async {
    if (index < 0 || index >= _servers.length) return;
    final generation = ++_generation;
    final old = _controller;
    setState(() { _loading = true; _error = null; _status = 'Switching to ${_servers[index]}…'; });
    await old?.pause();
    await old?.dispose();
    if (mounted) setState(() => _controller = null);
    await _tryFrom(index, generation);
  }

  Future<void> _switchType() async {
    _type = _type == 'sub' ? 'dub' : 'sub';
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (mounted) await _loadServers();
  }

  String _message(Object error) {
    if (error is TimeoutException) return 'Request timed out.';
    if (error is PlatformException) return error.message ?? 'Android could not read this HLS stream.';
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  Future<void> _toggleFullscreen() async {
    final value = !_fullscreen;
    await SystemChrome.setEnabledSystemUIMode(value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(value
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    if (mounted) setState(() => _fullscreen = value);
  }

  String _time(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}'
        : '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _generation++;
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
    final ready = video?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen ? null : AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_servers.isNotEmpty) PopupMenuButton<int>(
            tooltip: 'Change server',
            icon: const Icon(Icons.dns_outlined),
            onSelected: _chooseServer,
            itemBuilder: (_) => [
              for (var i = 0; i < _servers.length; i++)
                PopupMenuItem(value: i, child: Row(children: [
                  if (i == _selected) const Icon(Icons.check, color: appPurple, size: 18),
                  const SizedBox(width: 8), Text(_servers[i]),
                ])),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.closed_caption_outlined),
            onSelected: (v) {
              if (v == 'audio') _switchType();
              if (v == 'captions') setState(() => _captions = !_captions);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'captions', child: Text(_captions ? 'Subtitle preference: on' : 'Subtitle preference: off')),
              PopupMenuItem(value: 'audio', child: Text(_type == 'sub' ? 'Switch to dub' : 'Switch to sub')),
            ],
          ),
        ],
      ),
      body: SafeArea(child: Column(children: [
        Expanded(child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(alignment: Alignment.center, children: [
            if (ready)
              Center(child: AspectRatio(aspectRatio: video!.value.aspectRatio, child: VideoPlayer(video)))
            else
              const Center(child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 76)),
            if (_loading) Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: appPurple),
              const SizedBox(height: 14),
              Text(_status, style: const TextStyle(color: Colors.white70)),
            ]),
            if (_error != null && !_loading) Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                const Text('Playback unavailable', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: _loadServers, icon: const Icon(Icons.refresh), label: const Text('Retry servers')),
              ]),
            ),
            if (_controls && ready && !_loading) _buildControls(video!),
          ]),
        )),
        if (!_fullscreen) _buildFooter(),
      ])),
    );
  }

  Widget _buildControls(VideoPlayerController video) {
    final v = video.value;
    return Positioned.fill(child: Container(
      color: Colors.black.withValues(alpha: 0.28),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text('EP ${widget.episode}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          PopupMenuButton<double>(
            initialValue: _speed,
            color: const Color(0xFF202033),
            onSelected: (s) { setState(() => _speed = s); video.setPlaybackSpeed(s); },
            itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                .map((s) => PopupMenuItem(value: s, child: Text('${s}x', style: const TextStyle(color: Colors.white)))).toList(),
            child: Text('${_speed}x', style: const TextStyle(color: Colors.white)),
          ),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => video.seekTo(v.position - const Duration(seconds: 10)), icon: const Icon(Icons.replay_10, color: Colors.white, size: 34)),
          const SizedBox(width: 24),
          IconButton(onPressed: () => v.isPlaying ? video.pause() : video.play(), iconSize: 58,
            icon: Icon(v.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white)),
          const SizedBox(width: 24),
          IconButton(onPressed: () => video.seekTo(v.position + const Duration(seconds: 10)), icon: const Icon(Icons.forward_10, color: Colors.white, size: 34)),
        ]),
        Column(children: [
          VideoProgressIndicator(video, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 8),
            colors: const VideoProgressColors(playedColor: appPurple, bufferedColor: Colors.white38, backgroundColor: Colors.white12)),
          Row(children: [
            Text(_time(v.position), style: const TextStyle(color: Colors.white, fontSize: 11)),
            const Spacer(),
            Text(_time(v.duration), style: const TextStyle(color: Colors.white, fontSize: 11)),
            IconButton(onPressed: _toggleFullscreen, icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white)),
          ]),
        ]),
      ]),
    ));
  }

  Widget _buildFooter() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    color: const Color(0xFF10111C),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.anime.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 4),
      Text('Episode ${widget.episode} • ${_currentServer ?? (_loading ? 'Finding servers…' : 'No server selected')}',
        style: const TextStyle(color: appMuted)),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.subtitles_outlined, color: appPurple, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_captions ? 'Subtitle preference: on (if included in stream)' : 'Subtitle preference: off',
          style: const TextStyle(color: appMuted, fontSize: 12))),
        TextButton(onPressed: _switchType, child: Text(_type.toUpperCase())),
      ]),
    ]),
  );
}
