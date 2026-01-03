import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class CompareScreen extends ConsumerStatefulWidget {
  final String leftPath;
  final String rightPath;
  const CompareScreen({required this.leftPath, required this.rightPath, super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  late VideoPlayerController leftCtrl;
  late VideoPlayerController rightCtrl;
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    leftCtrl = widget.leftPath.startsWith('https') ? VideoPlayerController.network(widget.leftPath) : VideoPlayerController.file(File(widget.leftPath));
    rightCtrl = widget.rightPath.startsWith('https') ? VideoPlayerController.network(widget.rightPath) : VideoPlayerController.file(File(widget.rightPath));

    Future.wait([leftCtrl.initialize(), rightCtrl.initialize()]).then((_) {
      setState(() {
        initialized = true;
      });
      // Optionally set same playback speed & volume
      rightCtrl.setVolume(1.0);
      leftCtrl.setVolume(1.0);

      // Sync listeners: when left seeks, set right to same pos
      leftCtrl.addListener(() {
        if ((leftCtrl.value.isPlaying && !rightCtrl.value.isPlaying) || rightCtrl.value.isPlaying != leftCtrl.value.isPlaying) {
          // keep play/pause in sync
          if (leftCtrl.value.isPlaying && !rightCtrl.value.isPlaying) rightCtrl.play();
          if (!leftCtrl.value.isPlaying && rightCtrl.value.isPlaying) rightCtrl.pause();
        }
      });

      rightCtrl.addListener(() {
        if ((rightCtrl.value.isPlaying && !leftCtrl.value.isPlaying) || leftCtrl.value.isPlaying != rightCtrl.value.isPlaying) {
          if (rightCtrl.value.isPlaying && !leftCtrl.value.isPlaying) leftCtrl.play();
          if (!rightCtrl.value.isPlaying && leftCtrl.value.isPlaying) leftCtrl.pause();
        }
      });
    });
  }

  @override
  void dispose() {
    leftCtrl.dispose();
    rightCtrl.dispose();
    super.dispose();
  }

  void _seekAll(Duration pos) {
    leftCtrl.seekTo(pos);
    rightCtrl.seekTo(pos);
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final aspect = leftCtrl.value.aspectRatio;
    return Scaffold(
      appBar: AppBar(title: const Text("Compare")),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: AspectRatio(aspectRatio: aspect, child: VideoPlayer(leftCtrl))),
                Expanded(child: AspectRatio(aspectRatio: aspect, child: VideoPlayer(rightCtrl))),
              ],
            ),
          ),
          VideoProgressIndicator(leftCtrl, allowScrubbing: true, padding: const EdgeInsets.all(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.replay_10), onPressed: () {
                final newPos = leftCtrl.value.position - const Duration(seconds: 10);
                _seekAll(newPos >= Duration.zero ? newPos : Duration.zero);
              }),
              IconButton(icon: Icon(leftCtrl.value.isPlaying ? Icons.pause : Icons.play_arrow), onPressed: () {
                if (leftCtrl.value.isPlaying) {
                  leftCtrl.pause();
                  rightCtrl.pause();
                } else {
                  leftCtrl.play();
                  rightCtrl.play();
                }
                setState(() {});
              }),
              IconButton(icon: const Icon(Icons.forward_10), onPressed: () {
                final newPos = leftCtrl.value.position + const Duration(seconds: 10);
                final max = leftCtrl.value.duration;
                _seekAll(newPos <= max ? newPos : max);
              }),
            ],
          )
        ],
      ),
    );
  }
}
