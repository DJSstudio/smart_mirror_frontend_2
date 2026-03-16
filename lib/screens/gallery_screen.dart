import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../state/gallery_provider.dart';
import 'video_player_screen.dart';
import '../native/native_agent.dart';
import '../utils/env.dart';
import 'compare_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const GalleryScreen({super.key, required this.sessionId});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final List<String> _selectedVideoIds = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(galleryProvider.notifier).loadVideos(widget.sessionId);
    });
  }

  @override
  void dispose() {
    NativeAgent.showMirrorIdle();
    super.dispose();
  }

  void _toggleCompareSelection(String videoId) {
    setState(() {
      if (_selectedVideoIds.contains(videoId)) {
        _selectedVideoIds.remove(videoId);
      } else {
        if (_selectedVideoIds.length < 2) {
          _selectedVideoIds.add(videoId);
        }
      }
    });
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return "N/A";
    int totalSeconds = seconds.toInt();
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int secs = totalSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  Future<void> _copyVideoUrl(MirrorVideo video) async {
    final resolvedUrl = _resolveVideoUrl(video.url);
    await Clipboard.setData(ClipboardData(text: resolvedUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Video URL copied")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2ECE7),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final cardWidth = (maxWidth * 0.94).clamp(360.0, 980.0);
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B6661)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Gallery",
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B6661),
                          ),
                        ),
                        const Spacer(),
                        if (_selectedVideoIds.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _selectedVideoIds.clear()),
                            child: Text(
                              "Clear",
                              style: GoogleFonts.workSans(
                                fontSize: 12,
                                color: const Color(0xFF8C8681),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: cardWidth,
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 200,
                          child: videos.isEmpty
                              ? Center(
                                  child: Text(
                                    "No looks recorded yet",
                                    style: GoogleFonts.workSans(
                                      fontSize: 14,
                                      color: const Color(0xFF8C8681),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: videos.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final v = videos[index];
                                    final isSelected = _selectedVideoIds.contains(v.id);
                                    final selectionIndex =
                                        _selectedVideoIds.indexOf(v.id);

                                    return GestureDetector(
                                      onTap: () {
                                        final resolvedUrl = _resolveVideoUrl(v.url);
                                        if (Platform.isAndroid) {
                                          NativeAgent.playOnMirror(resolvedUrl);
                                          NativeAgent.openNativePlayer(resolvedUrl);
                                        } else {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => MirrorVideoPlayerScreen(
                                                videoUrl: resolvedUrl,
                                                playlistUrls: videos
                                                    .map((item) => _resolveVideoUrl(item.url))
                                                    .toList(),
                                                playlistIds: videos.map((item) => item.id).toList(),
                                                startIndex: index,
                                                sessionId: widget.sessionId,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      onLongPress: () => _toggleCompareSelection(v.id),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 140,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE5DED8),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.12),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: v.thumbnailUrl != null
                                                  ? Image.network(
                                                      v.thumbnailUrl!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stack) {
                                                        return const Center(
                                                          child: Icon(
                                                            Icons.play_circle_outline,
                                                            size: 40,
                                                            color: Color(0xFF8C8681),
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  : const Center(
                                                      child: Icon(
                                                        Icons.play_circle_outline,
                                                        size: 40,
                                                        color: Color(0xFF8C8681),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 8,
                                            left: 10,
                                            child: Text(
                                              "Look ${index + 1}",
                                              style: GoogleFonts.workSans(
                                                fontSize: 12,
                                                color: const Color(0xFF5F5A55),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 8,
                                            right: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.55),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _formatDuration(v.durationSeconds),
                                                style: GoogleFonts.workSans(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: InkWell(
                                              onTap: () => _toggleCompareSelection(v.id),
                                              child: Container(
                                                width: 26,
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(0xFF8E8077)
                                                      : Colors.white70,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    isSelected ? "${selectionIndex + 1}" : "+",
                                                    style: GoogleFonts.workSans(
                                                      fontSize: 12,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : const Color(0xFF6B6661),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            left: 8,
                                            child: InkWell(
                                              onTap: () => _copyVideoUrl(v),
                                              child: Container(
                                                width: 26,
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color: Colors.white70,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.content_copy,
                                                  size: 14,
                                                  color: Color(0xFF6B6661),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _pillAction(
                              label: "Compare",
                              enabled: _selectedVideoIds.length == 2,
                              onPressed: () {
                                final allVideos = ref.read(galleryProvider);
                                final selectedVideos = allVideos
                                    .where((v) => _selectedVideoIds.contains(v.id))
                                    .toList();

                                if (selectedVideos.length == 2) {
                                  final left = _resolveVideoUrl(selectedVideos[0].url);
                                  final right = _resolveVideoUrl(selectedVideos[1].url);
                                  if (Platform.isAndroid) {
                                    NativeAgent.compareOnMirror(left, right);
                                    NativeAgent.openNativeCompare(left, right);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CompareScreen(
                                          leftPath: left,
                                          rightPath: right,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            _pillAction(
                              label: "Export",
                              enabled: true,
                              onPressed: () {
                                Navigator.pushNamed(context, "/export");
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _resolveVideoUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }
    final base = Env.baseUrl;
    if (base.isEmpty) return trimmed;
    final root = base.replaceAll(RegExp(r"/api/?$"), "");
    if (trimmed.startsWith("/")) {
      return "$root$trimmed";
    }
    return "$root/$trimmed";
  }
}

Widget _pillAction({
  required String label,
  required bool enabled,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: 160,
    child: ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF1EAE6),
        disabledBackgroundColor: const Color(0xFFE8E1DC),
        foregroundColor: const Color(0xFF6B6661),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE4DDD7)),
        ),
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.12),
      ),
      child: Text(
        label,
        style: GoogleFonts.playfairDisplay(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF6B6661),
        ),
      ),
    ),
  );
}
