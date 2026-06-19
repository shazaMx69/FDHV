import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MemoryVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const MemoryVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<MemoryVideoPlayerScreen> createState() => _MemoryVideoPlayerScreenState();
}

class _MemoryVideoPlayerScreenState extends State<MemoryVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      _controller.addListener(_onPlayerUpdate);
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onPlayerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlayerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPlayerContent(),
            if (_initialized && _showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_error) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 64),
            SizedBox(height: 12),
            Text('Could not play video', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget _buildControls() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    final isPlaying = _controller.value.isPlaying;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: AppColors.primary,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _togglePlayPause,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(position),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  ' / ${_formatDuration(duration)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
