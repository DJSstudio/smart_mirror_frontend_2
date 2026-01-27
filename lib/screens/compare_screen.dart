import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../native/native_agent.dart';

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
  Timer? _syncTimer;
  bool _desiredPlaying = false;

  @override
  void initState() {
    super.initState();
    print("DEBUG: CompareScreen - Left: ${widget.leftPath}");
    print("DEBUG: CompareScreen - Right: ${widget.rightPath}");

    NativeAgent.compareOnMirror(widget.leftPath, widget.rightPath);
    
    leftCtrl = widget.leftPath.startsWith('http') 
        ? VideoPlayerController.network(widget.leftPath) 
        : VideoPlayerController.file(File(widget.leftPath));
    rightCtrl = widget.rightPath.startsWith('http') 
        ? VideoPlayerController.network(widget.rightPath) 
        : VideoPlayerController.file(File(widget.rightPath));

    Future.wait([leftCtrl.initialize(), rightCtrl.initialize()]).then((_) {
      print("DEBUG: Both videos initialized successfully");
      print("DEBUG: Left duration: ${leftCtrl.value.duration}");
      print("DEBUG: Right duration: ${rightCtrl.value.duration}");
      
      setState(() {
        initialized = true;
      });
      
      // Set volumes
      rightCtrl.setVolume(1.0);
      leftCtrl.setVolume(1.0);

      // Start both videos together
      _seekAll(Duration.zero);
      _setDesiredPlaying(true);

      // Start sync timer - constantly sync positions
      _startSyncTimer();
    }).catchError((error) {
      print("ERROR: Failed to initialize videos: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading videos: $error")),
        );
      }
    });
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      
      try {
        final left = leftCtrl.value;
        final right = rightCtrl.value;

        if (!left.isInitialized || !right.isInitialized) return;

        final leftDone =
            left.duration > Duration.zero && left.position >= left.duration;
        final rightDone =
            right.duration > Duration.zero && right.position >= right.duration;

        if (leftDone || rightDone) {
          _setDesiredPlaying(false);
          return;
        }

        // Enforce desired state without pausing the other controller.
        if (_desiredPlaying) {
          if (!left.isPlaying) leftCtrl.play();
          if (!right.isPlaying) rightCtrl.play();
        } else {
          if (left.isPlaying || right.isPlaying) {
            leftCtrl.pause();
            rightCtrl.pause();
          }
        }

        // Sync position - keep them within 150ms of each other.
        final posDiff = 
            (left.position.inMilliseconds - 
             right.position.inMilliseconds).abs();
        
        if (posDiff > 150 && left.isPlaying && right.isPlaying) {
          rightCtrl.seekTo(left.position);
        }
      } catch (e) {
        print("DEBUG: Error in sync timer: $e");
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    leftCtrl.dispose();
    rightCtrl.dispose();
    NativeAgent.hideMirror();
    super.dispose();
  }

  void _seekAll(Duration pos) {
    leftCtrl.seekTo(pos);
    rightCtrl.seekTo(pos);
  }

  void _setDesiredPlaying(bool playing) {
    if (_desiredPlaying == playing) return;
    if (mounted) {
      setState(() => _desiredPlaying = playing);
    } else {
      _desiredPlaying = playing;
    }
    if (playing) {
      leftCtrl.play();
      rightCtrl.play();
    } else {
      leftCtrl.pause();
      rightCtrl.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final showPlaying = _desiredPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            final controlsHeight = maxHeight > 700 ? 180.0 : 140.0;
            final topBarHeight = 48.0;
            final videoAreaHeight =
                maxHeight - controlsHeight - topBarHeight;
            return Column(
              children: [
                SizedBox(
                  height: topBarHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(
                  height: videoAreaHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildVideoPane(
                          leftCtrl,
                          "Video 1",
                          maxWidth / 2,
                          videoAreaHeight,
                        ),
                      ),
                      Expanded(
                        child: _buildVideoPane(
                          rightCtrl,
                          "Video 2",
                          maxWidth / 2,
                          videoAreaHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: controlsHeight,
                  child: Container(
                    color: Colors.black.withOpacity(0.65),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: leftCtrl,
                          builder: (context, value, child) {
                            final maxSeconds =
                                value.duration.inSeconds.toDouble();
                            final safeMax =
                                maxSeconds > 0 ? maxSeconds : 1.0;
                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 4,
                                    thumbShape:
                                        const RoundSliderThumbShape(
                                      enabledThumbRadius: 8,
                                    ),
                                  ),
                                  child: Slider(
                                    activeColor: Colors.white70,
                                    inactiveColor: Colors.white24,
                                    value: value.position.inSeconds
                                        .toDouble()
                                        .clamp(0, safeMax),
                                    max: safeMax,
                                    onChanged: (double seconds) {
                                      _seekAll(
                                        Duration(seconds: seconds.toInt()),
                                      );
                                    },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(value.position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(value.duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.replay_10),
                                color: Colors.white70,
                                onPressed: () {
                                  final newPos = leftCtrl.value.position -
                                      const Duration(seconds: 10);
                                  _seekAll(
                                    newPos >= Duration.zero
                                        ? newPos
                                        : Duration.zero,
                                  );
                                },
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white12,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  iconSize: 36,
                                  color: Colors.white,
                                  onPressed: () =>
                                      _setDesiredPlaying(!showPlaying),
                                  icon: AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(
                                      scale: anim,
                                      child: child,
                                    ),
                                    child: Icon(
                                      showPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      key: ValueKey(showPlaying),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_10),
                                color: Colors.white70,
                                onPressed: () {
                                  final newPos = leftCtrl.value.position +
                                      const Duration(seconds: 10);
                                  final max = leftCtrl.value.duration;
                                  _seekAll(newPos <= max ? newPos : max);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes =
        twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds =
        twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildVideoPane(
    VideoPlayerController controller,
    String label,
    double maxWidth,
    double maxHeight,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = controller.value.aspectRatio;
        var width = maxWidth;
        var height = width / aspect;
        if (height > maxHeight) {
          height = maxHeight;
          width = height * aspect;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VideoPlayer(controller),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
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
        );
      },
    );
  }
}
