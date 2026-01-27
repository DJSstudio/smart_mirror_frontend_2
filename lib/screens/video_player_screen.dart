import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../native/native_agent.dart';

class MirrorVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const MirrorVideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<MirrorVideoPlayerScreen> createState() => _MirrorVideoPlayerScreenState();
}

class _MirrorVideoPlayerScreenState extends State<MirrorVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    print("PLAYING VIDEO: ${widget.videoUrl}");

    NativeAgent.playOnMirror(widget.videoUrl);

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    NativeAgent.hideMirror();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _ready
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final maxHeight = constraints.maxHeight;
                  final controlsHeight = maxHeight > 700 ? 180.0 : 140.0;
                  final topBarHeight = 48.0;
                  final videoAreaHeight =
                      maxHeight - controlsHeight - topBarHeight;
                  final aspect = _controller.value.aspectRatio;
                  var width = maxWidth;
                  var height = width / aspect;
                  if (height > videoAreaHeight) {
                    height = videoAreaHeight;
                    width = height * aspect;
                  }
                  return Column(
                    children: [
                      SizedBox(
                        height: topBarHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: videoAreaHeight,
                        child: Center(
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: ClipRect(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: VideoPlayer(_controller),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      color: Colors.black.withOpacity(0.5),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        _formatDuration(
                                          _controller.value.duration,
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          color: Colors.black.withOpacity(0.55),
                          child: ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: _controller,
                            builder: (context, value, child) {
                              final maxSeconds =
                                  value.duration.inSeconds.toDouble();
                              final safeMax = maxSeconds > 0 ? maxSeconds : 1.0;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            value.isPlaying
                                                ? _controller.pause()
                                                : _controller.play();
                                          });
                                        },
                                        icon: Icon(
                                          value.isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${_formatDuration(value.position)} / ${_formatDuration(value.duration)}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape:
                                          const RoundSliderThumbShape(
                                        enabledThumbRadius: 8,
                                      ),
                                    ),
                                    child: Slider(
                                      activeColor: Colors.blue,
                                      inactiveColor: Colors.grey.shade700,
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
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
