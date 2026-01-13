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
      appBar: AppBar(title: const Text("Video Player")),
      body: SafeArea(
        child: _ready
            ? SingleChildScrollView(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Stack(
                          children: [
                            VideoPlayer(_controller),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  _formatDuration(
                                      _controller.value.duration),
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
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) {
                            return Column(
                              children: [
                                Text(
                                  "${_formatDuration(value.position)} / ${_formatDuration(value.duration)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8),
                                  ),
                                  child: Slider(
                                    activeColor: Colors.blue,
                                    inactiveColor: Colors.grey.shade700,
                                    value:
                                        value.position.inSeconds.toDouble(),
                                    max: value.duration.inSeconds
                                        .toDouble(),
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
              ),
            )
          : null,
    );
  }
}
