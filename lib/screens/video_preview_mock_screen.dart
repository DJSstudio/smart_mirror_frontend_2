import 'package:flutter/material.dart';

class VideoPreviewMockScreen extends StatelessWidget {
  final String videoId;

  const VideoPreviewMockScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Preview"),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // VIDEO PREVIEW PLACEHOLDER
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 96,
                  ),
                  const Positioned(
                    bottom: 20,
                    child: Text(
                      "Preview playback coming soon",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                ],
              ),
            ),
          ),

          // ACTION BAR — EXPORT ONLY
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text("Export"),
                onPressed: () {
                  Navigator.pushNamed(context, "/export");
                },
              ),
            ),
          ),

          // END SESSION
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  "/qr",
                  (route) => false,
                );
              },
              child: const Text(
                "End Session",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
