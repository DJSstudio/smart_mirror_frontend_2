import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _swapped = false;

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

  void _swapSides() {
    setState(() {
      final tmp = leftCtrl;
      leftCtrl = rightCtrl;
      rightCtrl = tmp;
      _swapped = !_swapped;
    });
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
    final labelLeft = _swapped ? "Look 2" : "Look 1";
    final labelRight = _swapped ? "Look 1" : "Look 2";

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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final maxHeight = constraints.maxHeight;
                final controlsHeight = maxHeight > 700 ? 150.0 : 120.0;
                final videoAreaHeight = maxHeight - controlsHeight - 40;
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
                          "Compare Looks",
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildVideoPane(
                              leftCtrl,
                              labelLeft,
                              maxWidth / 2,
                              videoAreaHeight,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildVideoPane(
                              rightCtrl,
                              labelRight,
                              maxWidth / 2,
                              videoAreaHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: controlsHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                                        enabledThumbRadius: 7,
                                      ),
                                    ),
                                    child: Slider(
                                      activeColor: const Color(0xFFC9BFB7),
                                      inactiveColor: const Color(0xFFE2DAD4),
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
                                        style: GoogleFonts.workSans(
                                          fontSize: 11,
                                          color: const Color(0xFF8C8681),
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(value.duration),
                                        style: GoogleFonts.workSans(
                                          fontSize: 11,
                                          color: const Color(0xFF8C8681),
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
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1EAE6),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: const Color(0xFFE4DDD7)),
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
                                  icon: Icons.swap_horiz,
                                  label: "Swap",
                                  onPressed: _swapSides,
                                ),
                                const SizedBox(width: 10),
                                _pillIcon(
                                  icon: Icons.replay_10,
                                  label: "Back",
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
                                const SizedBox(width: 10),
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    iconSize: 30,
                                    color: const Color(0xFF6B6661),
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
                                const SizedBox(width: 10),
                                _pillIcon(
                                  icon: Icons.forward_10,
                                  label: "Forward",
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
                  ],
                );
                  },
                ),
              ),
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
    return Center(
      child: SizedBox(
        width: maxWidth,
        height: maxHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 12,
                child: Text(
                  label,
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
