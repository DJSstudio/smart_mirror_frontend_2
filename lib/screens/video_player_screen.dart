import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import '../native/native_agent.dart';
import '../api/api_provider.dart';
import '../api/api_client.dart';
import '../state/gallery_provider.dart';

class MirrorVideoPlayerScreen extends ConsumerStatefulWidget {
  final String videoUrl;
  final List<String>? playlistUrls;
  final List<String>? playlistIds;
  final int? startIndex;
  final String? sessionId;

  const MirrorVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.playlistUrls,
    this.playlistIds,
    this.startIndex,
    this.sessionId,
  });

  @override
  ConsumerState<MirrorVideoPlayerScreen> createState() =>
      _MirrorVideoPlayerScreenState();
}

class _MirrorVideoPlayerScreenState
    extends ConsumerState<MirrorVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;
  int _index = 0;
  bool _deleting = false;
  bool _hasController = false;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex ?? 0;
    _loadVideo(_currentUrl());
  }

  @override
  void dispose() {
    if (_hasController) {
      _controller.dispose();
    }
    NativeAgent.hideMirror();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _currentUrl() {
    final list = widget.playlistUrls;
    if (list != null && list.isNotEmpty) {
      final safeIndex = _index.clamp(0, list.length - 1);
      return list[safeIndex];
    }
    return widget.videoUrl;
  }

  String? _currentId() {
    final ids = widget.playlistIds;
    if (ids == null || ids.isEmpty) return null;
    final safeIndex = _index.clamp(0, ids.length - 1);
    return ids[safeIndex];
  }

  Future<void> _loadVideo(String url) async {
    setState(() {
      _ready = false;
    });
    if (_hasController) {
      try {
        await _controller.dispose();
      } catch (_) {}
    }
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _hasController = true;
    await _controller.initialize();
    _controller.play();
    NativeAgent.playOnMirror(url);
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Future<void> _playNext() async {
    final list = widget.playlistUrls;
    if (list == null || list.isEmpty) return;
    if (_index + 1 >= list.length) return;
    _index += 1;
    await _loadVideo(_currentUrl());
  }

  Future<void> _deleteCurrent() async {
    final id = _currentId();
    if (id == null || _deleting) return;
    setState(() => _deleting = true);
    final api = ref.read(apiClientProvider);
    final res = await api.deleteVideo(id);
    if (res.ok) {
      if (widget.sessionId != null) {
        ref.read(galleryProvider.notifier).loadVideos(widget.sessionId!);
      }
      final list = widget.playlistUrls;
      final ids = widget.playlistIds;
      if (list != null && ids != null && list.isNotEmpty) {
        list.removeAt(_index);
        ids.removeAt(_index);
        if (list.isEmpty) {
          if (mounted) Navigator.pop(context);
        } else {
          if (_index >= list.length) _index = list.length - 1;
          await _loadVideo(_currentUrl());
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    }
    if (mounted) {
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2ECE7),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, outer) {
            final cardWidth = (outer.maxWidth * 0.96).clamp(480.0, 1180.0);
            return Center(
              child: Container(
                width: cardWidth,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2EE),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white70),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _ready
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final maxHeight = constraints.maxHeight;
                      final controlsHeight = maxHeight > 700 ? 150.0 : 120.0;
                      final videoAreaHeight =
                          maxHeight - controlsHeight - 40;
                      final aspect = _controller.value.aspectRatio;
                      var width = maxWidth;
                      var height = width / aspect;
                      if (height > videoAreaHeight) {
                        height = videoAreaHeight;
                        width = height * aspect;
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Color(0xFF6B6661),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Look ${_index + 1}",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B6661),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: videoAreaHeight,
                            child: Center(
                              child: SizedBox(
                                width: maxWidth,
                                height: videoAreaHeight,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    children: [
                                      // Blurred background to avoid black bars.
                                      Positioned.fill(
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                          child: SizedBox(
                                            width: _controller.value.size.width,
                                            height: _controller.value.size.height,
                                            child: VideoPlayer(_controller),
                                          ),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                          child: Container(
                                            color: Colors.black.withOpacity(0.25),
                                          ),
                                        ),
                                      ),
                                      // Foreground full-frame (no stretch).
                                      Center(
                                        child: SizedBox(
                                          width: width,
                                          height: height,
                                          child: VideoPlayer(_controller),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        left: 12,
                                        child: Text(
                                          "Look ${_index + 1}",
                                          style: GoogleFonts.workSans(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.85),
                                            fontWeight: FontWeight.w600,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 6,
                                                color: Colors.black.withOpacity(0.4),
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: controlsHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: _controller,
                                  builder: (context, value, child) {
                                    final maxSeconds =
                                        value.duration.inSeconds.toDouble();
                                    final safeMax =
                                        maxSeconds > 0 ? maxSeconds : 1.0;
                                    return SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                          enabledThumbRadius: 7,
                                        ),
                                      ),
                                      child: Slider(
                                        activeColor: const Color(0xFFC9BFB7),
                                        inactiveColor:
                                            const Color(0xFFE2DAD4),
                                        value: value.position.inSeconds
                                            .toDouble()
                                            .clamp(0, safeMax),
                                        max: safeMax,
                                        onChanged: (double seconds) {
                                          _controller.seekTo(
                                            Duration(seconds: seconds.toInt()),
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                ValueListenableBuilder<VideoPlayerValue>(
                                  valueListenable: _controller,
                                  builder: (context, value, child) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1EAE6),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                          color: const Color(0xFFE4DDD7),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _pillIcon(
                                            icon: Icons.video_library_outlined,
                                            label: _formatDuration(
                                              value.position,
                                            ),
                                            onPressed: () {},
                                          ),
                                          const SizedBox(width: 10),
                                          _pillIcon(
                                            icon: Icons.rotate_left,
                                            label: "Prev",
                                            onPressed: () {
                                              final newPos = value.position -
                                                  const Duration(seconds: 10);
                                              _controller.seekTo(
                                                newPos >= Duration.zero
                                                    ? newPos
                                                    : Duration.zero,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              iconSize: 30,
                                              color: const Color(0xFF6B6661),
                                              onPressed: () {
                                                value.isPlaying
                                                    ? _controller.pause()
                                                    : _controller.play();
                                              },
                                              icon: Icon(
                                                value.isPlaying
                                                    ? Icons.pause
                                                    : Icons.play_arrow,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          _pillIcon(
                                            icon: Icons.arrow_forward,
                                            label: "Next",
                                            onPressed: _playNext,
                                          ),
                                          const SizedBox(width: 10),
                                          _pillIcon(
                                            icon: Icons.delete_outline,
                                            label: _deleting ? "..." : "Delete",
                                            onPressed: _deleting
                                                ? () {}
                                                : _deleteCurrent,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                        },
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFB9B1AA),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _pillIcon({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return Row(
    children: [
      IconButton(
        icon: Icon(icon, color: const Color(0xFF6B6661)),
        onPressed: onPressed,
      ),
      Text(
        label,
        style: GoogleFonts.workSans(
          fontSize: 12,
          color: const Color(0xFF6B6661),
        ),
      ),
    ],
  );
}
