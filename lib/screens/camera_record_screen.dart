import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import '../native/native_agent.dart';
import '../state/session_provider.dart';
import '../state/recording_provider.dart';

class CameraRecordScreen extends ConsumerStatefulWidget {
  const CameraRecordScreen({super.key});

  @override
  ConsumerState<CameraRecordScreen> createState() =>
      _CameraRecordScreenState();
}

class _CameraRecordScreenState extends ConsumerState<CameraRecordScreen> {
  CameraController? controller;
  bool isRecording = false;
  String? sessionId;
  Timer? _countdownTimer;
  int? _countdown;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _recordingStart;

  @override
  void initState() {
    super.initState();
    sessionId = ref.read(sessionProvider)?.id;
    NativeAgent.showMirrorIdle();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final cam = cameras.first;

    controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (controller == null || controller!.value.isRecordingVideo) return;

    await controller!.startVideoRecording();

    _recordingStart = DateTime.now();
    _startElapsedTimer();
    setState(() => isRecording = true);

    // Notify backend (start)
    ref.read(recordingProvider.notifier).start(sessionId!);
  }

  void _startCountdown() {
    if (_countdownTimer != null || isRecording) return;
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final next = (_countdown ?? 0) - 1;
      if (next <= 0) {
        timer.cancel();
        _countdownTimer = null;
        setState(() => _countdown = null);
        await _startRecording();
      } else {
        setState(() => _countdown = next);
      }
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsed = Duration.zero;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _recordingStart == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_recordingStart!);
      });
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _recordingStart = null;
    _elapsed = Duration.zero;
  }

  Future<void> _stopRecording() async {
    if (controller == null || !controller!.value.isRecordingVideo) return;

    final XFile file = await controller!.stopVideoRecording();
    _stopElapsedTimer();
    setState(() => isRecording = false);

    print("DEBUG: Video saved locally → ${file.path}");

    // Backend upload
    final recorder = ref.read(recordingProvider.notifier);
    await recorder.stop(sessionId!, file.path);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    controller?.dispose();
    NativeAgent.hideMirror();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final camRatio = controller!.value.aspectRatio;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ----- FULL SCREEN CAMERA -----
          Transform.scale(
            scale: camRatio < deviceRatio
                ? deviceRatio / camRatio
                : camRatio / deviceRatio,
            child: Center(
              child: AspectRatio(
                aspectRatio: camRatio,
                child: CameraPreview(controller!),
              ),
            ),
          ),

          // ----- RECORDING INDICATOR -----
          if (isRecording)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.only(top: 12, left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
                      const SizedBox(width: 6),
                      const Text("REC", style: TextStyle(color: Colors.red, fontSize: 18)),
                      const SizedBox(width: 12),
                      Text(
                        _formatElapsed(_elapsed),
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_countdown != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                alignment: Alignment.center,
                child: Text(
                  _countdown.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // ----- RECORD BUTTON -----
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: isRecording
                    ? _stopRecording
                    : (_countdown == null ? _startCountdown : null),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording
                        ? Colors.red
                        : (_countdown == null ? Colors.white : Colors.white54),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 3,
                      )
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }
}
