import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
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

  @override
  void initState() {
    super.initState();
    sessionId = ref.read(sessionProvider)?.id;
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

    setState(() => isRecording = true);

    // Notify backend (start)
    ref.read(recordingProvider.notifier).start(sessionId!);
  }

  Future<void> _stopRecording() async {
    if (controller == null || !controller!.value.isRecordingVideo) return;

    final XFile file = await controller!.stopVideoRecording();
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
    controller?.dispose();
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
            const Positioned(
              top: 50,
              left: 20,
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
                  SizedBox(width: 6),
                  Text("REC", style: TextStyle(color: Colors.red, fontSize: 18)),
                ],
              ),
            ),

          // ----- RECORD BUTTON -----
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording ? Colors.red : Colors.white,
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

}
