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
  bool _portraitMirror = true;
  int _mirrorRotation = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await NativeAgent.showMirrorIdle();
      await DisplaySelectionService.forceMirrorToLargestExternal();
      await _loadMirrorOrientation();
    });
  }

  Future<void> _loadMirrorOrientation() async {
    final rotation = await NativeAgent.getMirrorRotation();
    if (!mounted) return;
    final normalized = switch (rotation) {
      90 || 180 || 270 => rotation!,
      _ => 0,
    };
    setState(() {
      _mirrorRotation = normalized;
      _portraitMirror = normalized == 90 || normalized == 270;
    });
  }

  Future<void> _setGlobalMirrorOrientation(bool portrait) async {
    final next = portrait
        ? (_mirrorRotation == 270 ? 270 : 90)
        : (_mirrorRotation == 180 ? 180 : 0);
    await NativeAgent.setMirrorRotation(next);
    if (!mounted) return;
    setState(() {
      _mirrorRotation = next;
      _portraitMirror = portrait;
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
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => CameraRecordScreen()),
                                    );
                                    await _loadMirrorOrientation();
                                  },
                                  textStyle: buttonTextStyle,
                                ),
                                const SizedBox(height: 18),
                                _softButton(
                                  context,
                                  label: "Gallery",
                                  onPressed: () async {
                                    await Navigator.pushNamed(
                                      context,
                                      "/gallery",
                                      arguments: {"session_id": session.id},
                                    );
                                    await _loadMirrorOrientation();
                                  },
                                  textStyle: buttonTextStyle,
                                ),
                                const SizedBox(height: 18),
                                _orientationIndicator(
                                  portrait: _portraitMirror,
                                  rotation: _mirrorRotation,
                                  onChanged: _setGlobalMirrorOrientation,
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

Widget _orientationIndicator({
  required bool portrait,
  required int rotation,
  required ValueChanged<bool> onChanged,
}) {
  final labelStyle = GoogleFonts.workSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF6B6661),
  );

  Widget segment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE7DDD6) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: labelStyle.copyWith(
                color: selected ? const Color(0xFF5E5650) : const Color(0xFF8A837E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1EAE6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE4DDD7)),
    ),
    child: Column(
      children: [
        Text(
          "Mirror View: ${portrait ? "Portrait" : "Landscape"} ($rotation°)",
          style: GoogleFonts.workSans(
            fontSize: 12,
            color: const Color(0xFF7A746E),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            segment(
              label: "Portrait",
              selected: portrait,
              onTap: () => onChanged(true),
            ),
            segment(
              label: "Landscape",
              selected: !portrait,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    ),
  );
}
