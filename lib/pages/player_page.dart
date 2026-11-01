import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme.dart';
import '../models/anime.dart';
import '../services/streaming_service.dart';

enum PlayerStatus {
  idle,
  fetchingSource,
  validatingSource,
  initializing,
  buffering,
  ready,
  playing,
  paused,
  completed,
  error,
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.anime, required this.episode});
  final Anime anime;
  final int episode;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final StreamingService _streaming = StreamingService();
  VideoPlayerController? _controller;
  List<StreamServer> _servers = [];
  List<Map<String, dynamic>> _subtitleTracks = [];
  final List<String> _failures = [];
  PlayerStatus _status = PlayerStatus.idle;
  int _selectedServer = -1;
  int _generation = 0;
  bool _fullscreen = false;
  bool _controlsVisible = true;
  bool _muted = false;
  bool _switching = false;
  String _type = 'sub';
  String? _currentServer;
  String? _error;
  double _speed = 1;
  final double _volume = 1;
  Timer? _hideTimer;
  Timer? _bufferTimer;
  Duration _savedPosition = Duration.zero;

  bool get _busy => {
    PlayerStatus.fetchingSource,
    PlayerStatus.validatingSource,
    PlayerStatus.initializing,
    PlayerStatus.buffering,
  }.contains(_status);

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadServers();
  }

  Future<void> _loadServers({int startAt = 0}) async {
    final generation = ++_generation;
    _failures.clear();
    _setStatus(PlayerStatus.fetchingSource, message: 'Finding streaming servers…');
    try {
      final servers = await _streaming.getServers(
        animeId: widget.anime.id,
        malId: widget.anime.malId,
        episode: widget.episode,
        type: _type,
      );
      if (!_active(generation)) return;
      setState(() => _servers = servers);
      await _tryServers(startAt, generation);
    } catch (error) {
      if (_active(generation)) _fail(error);
    }
  }

  Future<bool> _tryServers(int startAt, int generation) async {
    for (var i = startAt; i < _servers.length; i++) {
      if (!_active(generation)) return false;
      final server = _servers[i];
      try {
        _setStatus(PlayerStatus.fetchingSource, message: 'Requesting $server…');
        final source = await _streaming.resolve(
          animeId: widget.anime.id,
          malId: widget.anime.malId,
          episode: widget.episode,
          type: _type,
          server: server.name,
        );
        if (!_active(generation)) return false;
        _setStatus(PlayerStatus.initializing, message: 'Initializing ${server.name}…');
        await _startSource(source, i, generation);
        return true;
      } catch (error) {
        final message = '${server.name}: ${_errorText(error)}';
        _failures.add(message);
        debugPrint('[PLAYER] Playback failed: $message');
      }
    }
    if (_active(generation)) {
      _fail(Exception([
        'No available server could start playback.',
        ..._failures,
        'Direct M3U8 fallback is disabled.',
      ].join('\n')));
    }
    return false;
  }

  Future<void> _startSource(ResolvedStream source, int index, int generation) async {
    VideoPlayerController? next;
    try {
      next = VideoPlayerController.networkUrl(
        source.uri,
        httpHeaders: StreamingService.headers,
        formatHint: source.format == StreamFormat.hls ? VideoFormat.hls : VideoFormat.other,
      );
      await next.initialize().timeout(const Duration(seconds: 35));
      if (!_active(generation)) {
        await next.dispose();
        return;
      }
      await next.setLooping(false);
      await next.setPlaybackSpeed(_speed);
      await next.setVolume(_muted ? 0 : _volume);
      final duration = next.value.duration;
      final restore = _savedPosition;
      if (restore > Duration.zero && duration > Duration.zero && restore < duration) {
        await next.seekTo(restore);
      }

      final previous = _controller;
      setState(() {
        _controller = next;
        _selectedServer = index;
        _currentServer = source.server;
        _subtitleTracks = source.subtitles;
        _error = null;
        _status = PlayerStatus.ready;
      });
      next.addListener(() => _onControllerChanged(next!, generation));
      debugPrint('[PLAYER] Controller initialized: ${source.server}');
      await next.play().timeout(const Duration(seconds: 10));
      if (!_active(generation)) return;
      setState(() => _status = PlayerStatus.playing);
      await previous?.dispose();
      _scheduleHide();
    } catch (error) {
      await next?.dispose();
      rethrow;
    }
  }

  void _onControllerChanged(VideoPlayerController controller, int generation) {
    if (!_active(generation) || !identical(controller, _controller)) return;
    final value = controller.value;
    if (value.hasError && !_switching) {
      _savedPosition = value.position;
      final next = _selectedServer + 1;
      debugPrint('[PLAYER] Playback failed: ${value.errorDescription}');
      unawaited(_recoverToNext(next, generation, controller));
      return;
    }
    if (value.isBuffering) {
      if (_status != PlayerStatus.buffering) {
        setState(() => _status = PlayerStatus.buffering);
        debugPrint('[PLAYER] Buffering started');
      }
      _bufferTimer?.cancel();
      _bufferTimer = Timer(const Duration(seconds: 25), () {
        if (_active(generation) && identical(_controller, controller) && controller.value.isBuffering) {
          _recoverToNext(_selectedServer + 1, generation, controller);
        }
      });
    } else {
      _bufferTimer?.cancel();
      if (value.isCompleted) {
        setState(() => _status = PlayerStatus.completed);
      } else if (value.isPlaying) {
        if (_status != PlayerStatus.playing) {
          setState(() => _status = PlayerStatus.playing);
        }
        debugPrint('[PLAYER] Buffering ended / playback active');
      } else if (value.isInitialized && _status != PlayerStatus.paused) {
        setState(() => _status = PlayerStatus.ready);
      }
    }
  }

  Future<void> _recoverToNext(
    int nextIndex,
    int generation,
    VideoPlayerController old,
  ) async {
    if (_switching) return;
    _switching = true;
    _bufferTimer?.cancel();
    try {
      _savedPosition = old.value.position;
      await old.pause();
      await old.dispose();
      if (_active(generation) && identical(_controller, old)) {
        setState(() => _controller = null);
        await _tryServers(nextIndex, generation);
      }
    } finally {
      _switching = false;
    }
  }

  Future<void> _selectServer(int index) async {
    if (index < 0 || index >= _servers.length || index == _selectedServer) {
      return;
    }
    final old = _controller;
    _savedPosition = old?.value.position ?? Duration.zero;
    final generation = ++_generation;
    setState(() {
      _status = PlayerStatus.fetchingSource;
      _error = null;
    });
    await old?.pause();
    await old?.dispose();
    if (!_active(generation)) return;
    setState(() => _controller = null);
    await _tryServers(index, generation);
  }

  Future<void> _switchType() async {
    final old = _controller;
    _savedPosition = Duration.zero;
    _type = _type == 'sub' ? 'dub' : 'sub';
    await old?.pause();
    await old?.dispose();
    if (mounted) {
      setState(() => _controller = null);
    }
    await _loadServers();
  }

  bool _active(int generation) => mounted && generation == _generation;

  void _setStatus(PlayerStatus status, {String? message}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      if (message != null) _error = null;
    });
    if (message != null) debugPrint('[PLAYER] $message');
  }

  void _fail(Object error) {
    if (!mounted) return;
    _bufferTimer?.cancel();
    setState(() {
      _status = PlayerStatus.error;
      _error = _errorText(error);
    });
  }

  String _errorText(Object error) {
    if (error is TimeoutException) return 'The request timed out.';
    if (error is PlatformException) {
      return error.message ?? 'Android ExoPlayer could not read this stream.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) setState(() => _status = PlayerStatus.paused);
    } else {
      await controller.play();
      if (mounted) setState(() => _status = PlayerStatus.playing);
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
    if (_controlsVisible) _scheduleHide();
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
    _bufferTimer?.cancel();
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
            onSelected: _selectServer,
            itemBuilder: (_) => [
              for (var i = 0; i < _servers.length; i++)
                PopupMenuItem(value: i, child: Row(children: [
                  if (i == _selectedServer) const Icon(Icons.check, color: appPurple, size: 18),
                  const SizedBox(width: 8), Text(_servers[i].name),
                ])),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.closed_caption_outlined),
            onSelected: (value) {
              if (value == 'audio') _switchType();
              if (value == 'captions') {
                setState(() => _subtitleTracks.isEmpty ? _error = 'No external subtitle tracks are currently attached to this player.' : _error = 'Subtitle track selection requires a player with external VTT track support.');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'captions', child: Text('Subtitles (${_subtitleTracks.length} returned)')),
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
            if (_busy) Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: appPurple),
              const SizedBox(height: 14),
              Text(_status.name == 'validatingSource' ? 'Validating stream…' : _status.name == 'initializing' ? 'Initializing player…' : _status.name == 'buffering' ? 'Buffering…' : 'Connecting…',
                style: const TextStyle(color: Colors.white70)),
            ]),
            if (_status == PlayerStatus.error) Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                const SizedBox(height: 12),
                const Text('Playback unavailable', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_error ?? 'Unknown playback error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: _loadServers, icon: const Icon(Icons.refresh), label: const Text('Retry servers')),
              ]),
            ),
            if (_controlsVisible && ready && !_busy) _buildControls(video!),
          ]),
        )),
        if (!_fullscreen) _buildFooter(),
      ])),
    );
  }

  Widget _buildControls(VideoPlayerController video) {
    final value = video.value;
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
            onSelected: (speed) async {
              setState(() => _speed = speed);
              await video.setPlaybackSpeed(speed);
            },
            itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
                .map((speed) => PopupMenuItem(value: speed, child: Text('${speed}x', style: const TextStyle(color: Colors.white)))).toList(),
            child: Text('${_speed}x', style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            tooltip: _muted ? 'Unmute' : 'Mute',
            onPressed: () async {
              _muted = !_muted;
              await video.setVolume(_muted ? 0 : _volume);
              if (mounted) setState(() {});
            },
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
          ),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => video.seekTo(value.position - const Duration(seconds: 10)), icon: const Icon(Icons.replay_10, color: Colors.white, size: 34)),
          const SizedBox(width: 24),
          IconButton(onPressed: _togglePlay, iconSize: 58, icon: Icon(value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white)),
          const SizedBox(width: 24),
          IconButton(onPressed: () => video.seekTo(value.position + const Duration(seconds: 10)), icon: const Icon(Icons.forward_10, color: Colors.white, size: 34)),
        ]),
        Column(children: [
          VideoProgressIndicator(video, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 8),
            colors: const VideoProgressColors(playedColor: appPurple, bufferedColor: Colors.white38, backgroundColor: Colors.white12)),
          Row(children: [
            Text(_time(value.position), style: const TextStyle(color: Colors.white, fontSize: 11)),
            const Spacer(),
            Text(_time(value.duration), style: const TextStyle(color: Colors.white, fontSize: 11)),
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
      Text('Episode ${widget.episode} • ${_currentServer ?? (_busy ? 'Connecting…' : 'No server selected')}',
        style: const TextStyle(color: appMuted)),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.subtitles_outlined, color: appPurple, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('${_subtitleTracks.length} subtitle tracks returned • ${_type.toUpperCase()}',
          style: const TextStyle(color: appMuted, fontSize: 12))),
        TextButton(onPressed: _switchType, child: Text(_type.toUpperCase())),
      ]),
    ]),
  );
}
