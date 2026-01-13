import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/gallery_provider.dart';
import 'video_player_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(galleryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gallery"),
        actions: [
          if (_selectedVideoIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selectedVideoIds.clear()),
              child: const Text(
                "Clear",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: videos.isEmpty
                ? const Center(child: Text("No videos recorded"))
                : ListView.builder(
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final v = videos[index];
                      final isSelected = _selectedVideoIds.contains(v.id);
                      final selectionIndex =
                          _selectedVideoIds.indexOf(v.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // THUMBNAIL
                              Stack(
                                children: [
                                  Container(
                                    height: 160,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade900,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: v.thumbnailUrl != null
                                        ? Image.network(
                                            v.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Center(
                                                child: Icon(
                                                  Icons.play_circle_outline,
                                                  size: 64,
                                                  color: Colors.white70,
                                                ),
                                              );
                                            },
                                          )
                                        : const Center(
                                            child: Icon(
                                              Icons.play_circle_outline,
                                              size: 64,
                                              color: Colors.white70,
                                            ),
                                          ),
                                  ),
                                  // Duration Badge
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      child: Text(
                                        _formatDuration(v.durationSeconds),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.blue,
                                        child: Text(
                                          "${selectionIndex + 1}",
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Text(
                                "Video ${index + 1}",
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                "${v.size ~/ 1024} KB • ${_formatDuration(v.durationSeconds)}",
                                style: const TextStyle(
                                    color: Colors.grey),
                              ),

                              const SizedBox(height: 8),

                              // ACTION ROW
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text("Play"),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                MirrorVideoPlayerScreen(
                                                    videoUrl: v.url),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.compare),
                                      label: Text(
                                        isSelected
                                            ? "Selected"
                                            : "Compare",
                                      ),
                                      onPressed: () =>
                                          _toggleCompareSelection(v.id),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),

            // COMPARE CTA
            if (_selectedVideoIds.length == 2)
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.compare),
                    label: const Text("Compare Selected Videos"),
                    onPressed: () {
                      // Get the selected video URLs
                      final allVideos = ref.read(galleryProvider);
                      final selectedVideos = allVideos
                          .where((v) => _selectedVideoIds.contains(v.id))
                          .toList();
                      
                      if (selectedVideos.length == 2) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompareScreen(
                              leftPath: selectedVideos[0].url,
                              rightPath: selectedVideos[1].url,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("Export"),
                  onPressed: () {
                    Navigator.pushNamed(context, "/export");
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
