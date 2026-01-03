import 'package:flutter/material.dart';

class CompareScreenMock extends StatelessWidget {
  const CompareScreenMock({super.key});

  Widget _mockVideo(String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.play_circle_outline,
              size: 72,
              color: Colors.white70,
            ),
            Positioned(
              bottom: 16,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Compare"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _mockVideo("Video 1"),
                _mockVideo("Video 2"),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "Side-by-side comparison",
              style: TextStyle(color: Colors.white54),
            ),
          ),

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
