// lib/screens/active_session_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_provider.dart';
import '../state/recording_provider.dart';
import '../api/api_provider.dart';
import 'camera_record_screen.dart';

class ActiveSessionScreen extends ConsumerWidget {
  const ActiveSessionScreen({super.key});

  Future<void> _endSession(BuildContext context, WidgetRef ref, String sessionId) async {
    final api = ref.read(apiClientProvider);

    final resp = await api.post("/session/end", body: {"session_id": sessionId});

    if (resp.ok) {
      ref.read(sessionProvider.notifier).state = null;
      Navigator.pushReplacementNamed(context, "/login");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${resp.data}")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    if (session == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, "/login"));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // HEADER
              Column(
                children: const [
                  Text(
                    "SMART MIRROR",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Record. Compare. Decide.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // MIRROR PREVIEW PLACEHOLDER
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_outline,
                      size: 120,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // PRIMARY ACTION — RECORD
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CameraRecordScreen()),
                    );
                  },
                  child: const Text(
                    "Start Recording",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // SECONDARY ACTION — GALLERY
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      "/gallery",
                      arguments: {"session_id": session.id},
                    );
                  },
                  child: const Text(
                    "View Gallery",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // END SESSION (SUBTLE)
              TextButton(
                onPressed: () => _endSession(context, ref, session.id),
                child: const Text(
                  "End Session",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
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
