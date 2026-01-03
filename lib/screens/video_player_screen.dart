import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Video Player")),
      body: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
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
