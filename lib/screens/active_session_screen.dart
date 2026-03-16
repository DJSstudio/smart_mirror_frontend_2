// lib/screens/active_session_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_provider.dart';
import '../state/session_provider.dart';
import '../native/native_agent.dart';
import '../services/display_selection_service.dart';
import 'camera_record_screen.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await NativeAgent.showMirrorIdle();
      await DisplaySelectionService.forceMirrorToLargestExternal();
    });
  }

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
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, "/login"));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final labelStyle = GoogleFonts.workSans(
      fontSize: 12,
      color: const Color(0xFF6A6661),
      letterSpacing: 0.4,
    );
    final buttonTextStyle = GoogleFonts.playfairDisplay(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF6B6661),
      letterSpacing: 0.2,
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF2ECE7),
                  Color(0xFFE6DED8),
                  Color(0xFFF4EEEA),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "Welcome to the Smart Choice!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B6661),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final cardWidth = (maxWidth * 0.82).clamp(320.0, 720.0);
                        return Center(
                          child: Container(
                            width: cardWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 28,
                            ),
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
                                _softButton(
                                  context,
                                  label: "Record Look",
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CameraRecordScreen()),
                                    );
                                  },
                                  textStyle: buttonTextStyle,
                                ),
                                const SizedBox(height: 18),
                                _softButton(
                                  context,
                                  label: "Gallery",
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      "/gallery",
                                      arguments: {"session_id": session.id},
                                    );
                                  },
                                  textStyle: buttonTextStyle,
                                ),
                                const SizedBox(height: 18),
                                Text("Session ID: ${session.id}", style: labelStyle),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, "/hdmi_debug"),
                    child: Text(
                      "HDMI Debug",
                      style: GoogleFonts.workSans(
                        fontSize: 13,
                        color: const Color(0xFF7D756F),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _endSession(context, ref, session.id),
                    child: Text(
                      "End Session",
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        color: const Color(0xFF9E4B4B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _softButton(
  BuildContext context, {
  required String label,
  required VoidCallback onPressed,
  required TextStyle textStyle,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF1EAE6),
        foregroundColor: textStyle.color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE4DDD7)),
        ),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.15),
      ),
      onPressed: onPressed,
      child: Text(label, style: textStyle),
    ),
  );
}
